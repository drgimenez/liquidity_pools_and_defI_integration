//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "src/abstracts/Adapter.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

contract AAVE_Adapter is ReentrancyGuard, Adapter {

    constructor() Adapter() {}

    function openPosition(address _pool, address _token, address _user, uint256 _amount) external 
    nonReentrant() 
    onlyOwner()
    isValidAddress(_pool)
    isValidAddress(_token)
    isValidAddress(_user)
    isZeroAmount(_amount)
    returns(bool)
    {
        // Try call supply in the pool
        try IPool(_pool).supply(_token, _amount, _user, 0) {
            return true;
        }
        catch Error(string memory _errorMessage) {
            revert(_errorMessage);
        }
    }

    /// Modifiers

    modifier isZeroAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }
}
