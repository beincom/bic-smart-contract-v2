// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;


/* solhint-disable reason-string */

import "../interfaces/PaymasterErrors.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * Helper class for creating a paymaster.
 * provides helper methods for staking.
 * validates that the postOp is called only by the entryPoint
 */
abstract contract BasePaymasterUpgradeable is IPaymaster, OwnableUpgradeable, PaymasterErrors {
    IEntryPoint public entryPoint;


    function __BasePaymasterUpgradeable_init(
        address _entryPoint
    ) internal onlyInitializing {
        __Ownable_init(_msgSender());
        setEntryPoint(_entryPoint);
    }

    function setEntryPoint(address _entryPoint) public onlyOwner {
        entryPoint = IEntryPoint(_entryPoint);
    }

    /// @inheritdoc IPaymaster
    function validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
    external override returns (bytes memory context, uint256 validationData) {
         _requireFromEntryPoint();
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
    internal virtual returns (bytes memory context, uint256 validationData);

    /// @inheritdoc IPaymaster
    function postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) external override {
         _requireFromEntryPoint();
        _postOp(mode, context, actualGasCost);
    }

    /**
     * post-operation handler.
     * (verified to be called only through the entryPoint)
     * @dev if subclass returns a non-empty context from validatePaymasterUserOp, it must also implement this method.
     * @param mode enum with the following options:
     *      opSucceeded - user operation succeeded.
     *      opReverted  - user op reverted. still has to pay for gas.
     *      postOpReverted - user op succeeded, but caused postOp (in mode=opSucceeded) to revert.
     *                       Now this is the 2nd call, after user's op was deliberately reverted.
     * @param context - the context value returned by validatePaymasterUserOp
     * @param actualGasCost - actual gas used so far (without this postOp call).
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal virtual {

        (mode,context,actualGasCost); // unused params
        // subclass must override this method if validatePaymasterUserOp returns a context
        revert("must override");
    }

     /**
      * withdraw value from the deposit
      * @param withdrawAddress target to send to
      * @param amount to withdraw
      */
     function withdrawTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
         entryPoint.withdrawTo(withdrawAddress, amount);
     }
     /**
      * add stake for this paymaster.
      * This method can also carry eth value to add to the current stake.
      * @param unstakeDelaySec - the unstake delay for this paymaster. Can only be increased.
      */
     function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
         entryPoint.addStake{value : msg.value}(unstakeDelaySec);
     }

     /**
      * unlock the stake, in order to withdraw it.
      * The paymaster can't serve requests once unlocked, until it calls addStake again
      */
     function unlockStake() external onlyOwner {
         entryPoint.unlockStake();
     }

     /**
      * withdraw the entire paymaster's stake.
      * stake must be unlocked first (and then wait for the unstakeDelay to be over)
      * @param withdrawAddress the address to send withdrawn value.
      */
     function withdrawStake(address payable withdrawAddress) external onlyOwner {
         entryPoint.withdrawStake(withdrawAddress);
     }

     // validate the call is made from a valid entrypoint
     function _requireFromEntryPoint() internal virtual {
        if (_msgSender() != address(entryPoint)) {
            revert PaymasterNotEntryPoint(_msgSender());
        }
     }
}
