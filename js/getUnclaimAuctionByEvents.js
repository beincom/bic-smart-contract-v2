const { createPublicClient, http, padHex, toHex, keccak256, hexToBigInt} = require('viem');
const { arbitrumSepolia } = require('viem/chains');
const marketplaceAbi = require('./abis/marketplace.json');

const marketplaceAddress = '0xc8B727586901E1222f72c56804EC98a3F85C4dad';
const fromBlock = 133750967n;

const client = createPublicClient({
  chain: arbitrumSepolia,
  transport: http(),
});

async function main() {
  // auctionId -> status object
  /** @type {Record<string, { auctionId: bigint, endTimestamp: bigint, closed: boolean, closedTwice: boolean }>} */
  const auctionStatusById = {};

  // Fetch NewAuction and AuctionClosed logs in parallel
  const [newAuctionLogs, closedLogs, newBidLogs] = await Promise.all([
    client.getContractEvents({
      address: marketplaceAddress,
      abi: marketplaceAbi,
      eventName: 'NewAuction',
      fromBlock,
      toBlock: 'latest',
    }),
    client.getContractEvents({
      address: marketplaceAddress,
      abi: marketplaceAbi,
      eventName: 'AuctionClosed',
      fromBlock,
      toBlock: 'latest',
    }),
    client.getContractEvents({
      address: marketplaceAddress,
      abi: marketplaceAbi,
      eventName: 'NewBid',
      fromBlock,
      toBlock: 'latest',
    }),
  ]);

  // Build/refresh endTimestamp from NewAuction
  for (const log of newAuctionLogs) {
    const auctionId = log.args.auctionId;
    const endTimestamp = log.args.auction.endTimestamp;

    const key = auctionId.toString();
    const existing = auctionStatusById[key];
    if (!existing) {
      auctionStatusById[key] = {
        auctionId,
        endTimestamp,
        closed: false,
        closedTwice: false,
      };
    } else {
      // If multiple NewAuction logs for same id, keep the latest endTimestamp seen
      auctionStatusById[key].endTimestamp = endTimestamp;
    }
  }

  // Apply AuctionClosed events
  for (const log of closedLogs) {
    const auctionId = log.args.auctionId;
    const key = auctionId.toString();
    if (!auctionStatusById[key]) {
      auctionStatusById[key] = {
        auctionId,
        endTimestamp: 0n,
        closed: true,
        closedTwice: false,
      };
    } else {
      if (auctionStatusById[key].closed) {
        auctionStatusById[key].closedTwice = true;
      }
      auctionStatusById[key].closed = true;
    }
  }

  const bidAuctionIds = {}
    // Ensure auctionIds from NewBid are also in the status map
  for (const log of newBidLogs) {
    const auctionId = log.args.auctionId;
    const key = auctionId.toString();
    bidAuctionIds[key] = true;
  }

  const nowSec = BigInt(Math.floor(Date.now() / 1000));

  const notReachedEnd = [];
  const notClosed = [];
  const closedNotTwice = [];

  for (const status of Object.values(auctionStatusById)) {
    const { auctionId, endTimestamp, closed, closedTwice } = status;
    if (!closed && endTimestamp > nowSec || !bidAuctionIds[auctionId.toString()]) {
      notReachedEnd.push(Number(auctionId));
    } else if (!closed && endTimestamp <= nowSec) {
      notClosed.push(Number(auctionId));
    } else if (closed && !closedTwice) {
      closedNotTwice.push(Number(auctionId));
    }
  }

  // console.log('Number of auction ids cannot be closed because not reach endTimestamp or not been bid:', notReachedEnd.length);
  // console.log('Number of auction ids not been closed:', notClosed.length);
  // console.log('Number of auction ids been closed but not been closedTwice:', closedNotTwice.length);
  // console.log('AuctionIds cannot be closed because not reach endTimestamp or not been bid:', notReachedEnd);
  // console.log('AuctionIds not been closed:', notClosed);
  // console.log('AuctionIds been closed but not been closedTwice:', closedNotTwice);

  const auctionIdsNeedToClosePayout = [];
  const auctionIdsNeedToCloseTokens = [];

  for (const auctionId of notClosed) {
    auctionIdsNeedToClosePayout.push(auctionId);
    auctionIdsNeedToCloseTokens.push(auctionId);
  }
  for (const auctionId of closedNotTwice) {
    const status = await getPayoutStatus(auctionId);
    if (!status.paidOutBidAmount) {
      auctionIdsNeedToClosePayout.push(auctionId);
    }
    if (!status.paidOutAuctionTokens) {
      auctionIdsNeedToCloseTokens.push(auctionId);
    }
  }

  // console.log('Number of auction ids need to close payout:', auctionIdsNeedToClosePayout.length);
  // console.log('Number of auction ids need to close tokens:', auctionIdsNeedToCloseTokens.length);
  // console.log('AuctionIds need to close payout:', auctionIdsNeedToClosePayout);
  // console.log('AuctionIds need to close tokens:', auctionIdsNeedToCloseTokens);

  return {auctionIdsNeedToClosePayout, auctionIdsNeedToCloseTokens};
  // return {auctionIdsNeedToClosePayout: [], auctionIdsNeedToCloseTokens: []};
}


async function getPayoutStatus(auctionId) {
    try {
      const ENGLISH_AUCTIONS_STORAGE_POSITION = '0x89032daddd224983b4d69fda31dc440901185d9636f6e798dbe1e433d9d34c00'
      // Diamond storage layout calculation:
      // 1. Start with the EnglishAuctionsStorage position
      // 2. The Data struct inside it has:
      //    - totalAuctions at slot 0 (relative to storage position)
      //    - auctions mapping at slot 1
      //    - winningBid mapping at slot 2
      //    - payoutStatus mapping at slot 3
  
      // Calculate the storage slot for our auctionId in the payoutStatus mapping:
      // slot = keccak256(abi.encode(auctionId, ENGLISH_AUCTIONS_STORAGE_POSITION + 3))
  
      // Calculate the base slot for the mapping (storage position + 3)
      const baseSlot = hexToBigInt(ENGLISH_AUCTIONS_STORAGE_POSITION) + 3n
  
      // Encode and hash the key (auctionId) and base slot
      const paddedAuctionId = padHex(toHex(auctionId), { size: 32 })
      const paddedSlot = padHex(toHex(baseSlot), { size: 32 })
      const concatenated = paddedAuctionId.slice(2) + paddedSlot.slice(2)
      const slot = keccak256(`0x${concatenated}`)
      const storageValue = await client.getStorageAt({
          address: marketplaceAddress,
          slot: slot
      })
      const value = BigInt(storageValue)
      const paidOutAuctionTokens = (value & 1n) === 1n
      const paidOutBidAmount = (value & 256n) === 256n // Checking bit 8 (2^8 = 256)
  
      return {
        paidOutAuctionTokens,
        paidOutBidAmount
      }
      } catch (error) {
      console.error('Error reading payoutStatus:', error)
      return null
    }
}

main().then(({auctionIdsNeedToClosePayout, auctionIdsNeedToCloseTokens}) => {
  // Output as JSON string for the Solidity contract to parse
  const result = JSON.stringify({auctionIdsNeedToClosePayout, auctionIdsNeedToCloseTokens});
  process.stdout.write(result);
}).catch((err) => {
  console.error(err);
  process.exit(1);
});

// // Mock return data
// const result = `{"auctionIdsNeedToClosePayout":[5,6,7,9,10,11,12,13,14,15,16,17,18,19,20,23,25,27,29,30,31,32,33,34,36,37,38,166,219,276,277,377,588,621,622,824,825,901,913,936,963,974,998,1208,1241,1449,8,21,24,26,50,61,162,164,189,201,223,224,270,322,379,627,629,763,764,770,816,978,980,982,983,1020,1027,1100,1143,1152,1178,1179,1189,1192,1196,1197,1211,1212,1216,1219,1222,1224,1225,1234,1244,1271,1275,1276,1451],"auctionIdsNeedToCloseTokens":[5,6,7,9,10,11,12,13,14,15,16,17,18,19,20,23,25,27,29,30,31,32,33,34,36,37,38,166,219,276,277,377,588,621,622,824,825,901,913,936,963,974,998,1208,1241,1449,39,40,42,45,46,51,53,54,55,56,57,60,88,105,106,108,120,131,132,145,148,150,151,168,169,170,173,175,176,178,182,183,191,192,195,197,198,209,211,216,220,226,227,228,230,231,232,233,250,251,252,253,264,273,275,284,285,286,287,288,289,290,291,292,294,296,297,298,302,303,305,306,308,309,310,311,312,318,319,320,321,325,326,328,330,331,332,334,339,342,345,355,356,358,359,360,361,365,368,372,373,374,378,381,383,386,388,389,390,391,392,395,398,399,406,407,412,413,414,415,416,417,418,419,420,421,422,423,425,426,436,439,476,484,489,492,493,494,495,498,499,500,506,512,517,520,521,522,523,525,528,536,541,542,544,545,546,547,553,554,563,565,568,577,578,581,582,587,595,596,597,598,611,612,618,620,623,624,639,640,641,642,643,644,645,659,660,661,662,663,681,682,684,685,686,692,694,705,706,708,709,710,711,712,721,724,743,744,746,747,748,752,755,757,760,761,762,768,769,771,772,773,774,775,776,777,778,779,780,781,782,783,784,785,786,787,788,789,790,791,792,793,794,795,796,797,798,799,800,801,806,810,819,821,911,999,1000,1001,1002,1013,1014,1022,1024,1025,1034,1054,1067,1069,1077,1078,1082,1083,1084,1091,1092,1095,1098,1102,1104,1105,1130,1133,1134,1135,1136,1140,1145,1146,1147,1148,1158,1159,1176,1182,1217,1242,1266,1272,1273,1277,1280,1284,1306,1308,1314,1332,1333,1345,1347,1357,1364,1369,1370,1372,1373,1374,1375,1378,1389,1405,1426,1429,1444,1446,1447,1450]}`
// process.stdout.write(result);

