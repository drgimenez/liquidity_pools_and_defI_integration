//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "src/context/Auth.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract Adapter is ReentrancyGuard, Auth {

    address public protocolGatewayAddress;

    constructor() Auth(msg.sender) {}

    function setProtocolGatewayAddress(address _protocolGatewayAddress) external 
    onlyOwner() 
    isZeroAddress(_protocolGatewayAddress) 
    {
        protocolGatewayAddress = _protocolGatewayAddress;
    }

    /// Modifier

    modifier isValidAddress(address _protocolGatewayAddress) {
        if (_protocolGatewayAddress == address(0) || !_isContract(_protocolGatewayAddress)) revert InvalidAddress();
        _;
    }

    /// Internal functions

    function _isContract(address _account) internal view returns (bool) {
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        bytes32 codeHash;    
        assembly { codeHash := extcodehash(_account) }
        return (codeHash != accountHash && codeHash != 0x0);
    }

    /// Errors

    error InvalidAddress();
}