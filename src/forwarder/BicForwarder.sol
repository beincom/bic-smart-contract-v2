// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IBicForwarder} from "../interfaces/IBicForwarder.sol";

contract BicForwarder is IBicForwarder, Ownable {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    mapping(address => bool) public isController;
    /**
     * @notice Ensures that the function is called only by the controller.
     */

    constructor(address _owner) Ownable(_owner) {}
    
    modifier onController() {
        require(
            isController[msg.sender],
            "BicForwarder: caller is not a controller"
        );
        _;
    }

    function addController(address _controller) external onlyOwner {
        isController[_controller] = true;
    }

    function forwardRequest(RequestData memory requestData) external onController override {
        (bool success, bytes memory returnData) = requestData.to.call{value: requestData.value}(
            abi.encodePacked(requestData.data, requestData.from)
        );
        if (!success) {
            // Get the reason for the failed transaction
            string memory reason = _getRevertReason(returnData);
            revert(reason);
        }
        emit Requested(msg.sender, requestData.from, requestData.to, requestData.data, requestData.value);
    }

    /**
     * @notice Internal function to get the revert reason from the return data
     * @param _returnData The return data from the external call
     * @return The revert reason string
     */
    function _getRevertReason(bytes memory _returnData) internal pure returns (string memory) {
        // If the _returnData length is less than 68, then the transaction failed silently (without a revert message)
        // 68 bytes = 4 bytes (function selector) + 32 bytes (offset) + 32 bytes (string length)
        if (_returnData.length < 68) {
            return "Forwarding request failed";
        }
        assembly {
            // Slice the sighash (first 4 bytes of the _returnData)
            // This skips the function selector (0x08c379a0 for Error(string)) to get to the actual error message
            _returnData := add(_returnData, 0x04)
        }
        // Decode the remaining data as a string, which contains the actual revert message
        return abi.decode(_returnData, (string));
    }
}
