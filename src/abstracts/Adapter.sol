//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "src/context/Auth.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';

abstract contract Adapter is ReentrancyGuard, Auth {

    /// State variables
    address public protocolGatewayAddress;

    /// Constructor
    constructor() Auth(msg.sender) {}

    /// Functions

    /// ---------------------------------------------------------------------------------------------
    /// @notice Set the address of the protocol gateway to connect to this adapter
    /// @dev Throw if the sender is not an owner with error NotAnOwner()
    /// @dev Throw if the protocol gateway address is zero with error ZeroAddress()
    /// --------------------------------------------------------------------------------------------
    /// @param _protocolGatewayAddress The address of the protocol gateway to connect to this adapter
    /// --------------------------------------------------------------------------------------------
    function setProtocolGatewayAddress(address _protocolGatewayAddress) external 
    onlyOwner() 
    isZeroAddress(_protocolGatewayAddress) 
    {
        protocolGatewayAddress = _protocolGatewayAddress;
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Open a position in the protocol connected to this adapter
    /// @dev Implement non-reentry with OpenZeppelin's ReentrancyGuard
    /// @dev Throw if the sender is not an owner with error NotAnOwner(). The treasury contract is an owner.
    /// @dev Throw if the token address is zero or not a contract with error InvalidAddress()
    /// @dev Throw if the token receiver address is zero or not a contract with error InvalidAddress()
    /// @dev Throw if the amount is zero with error ZeroAmount()
    /// --------------------------------------------------------------------------------------------
    /// @param _underlyingAsset Address of the underlying asset token used to open the positions
    /// @param _tokenReceiver Address of the account that will receive the tokens provided by the 
    /// protocol connected to this adapter
    /// @param _amount Amount of tokens to open the position
    /// --------------------------------------------------------------------------------------------
    /// @return _success True if the position was opened successfully
    /// --------------------------------------------------------------------------------------------
    function openPosition(address _underlyingAsset, address _tokenReceiver, uint256 _amount) external virtual returns(bool _success) {
        revert NotImplemented(_underlyingAsset, _tokenReceiver, _amount);
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Close a position in the protocol connected to this adapter
    /// @dev Implement non-reentry with OpenZeppelin's ReentrancyGuard
    /// @dev Throw if the sender is not an owner with error NotAnOwner(). The treasury contract is an owner.
    /// @dev Throw if the token address is zero or not a contract with error InvalidAddress()
    /// @dev Throw if the token receiver address is zero or not a contract with error InvalidAddress()
    /// @dev Throw if the amount is zero with error ZeroAmount()
    /// --------------------------------------------------------------------------------------------
    /// @param _underlyingAsset Token address of the underlying asset used to open the positions to be closed
    /// @param _tokenReceiver Address of the account that will receive the withdrawn tokens 
    /// @param _amount Amount of tokens to withdraw from the position
    /// --------------------------------------------------------------------------------------------
    /// @return _tokensReceived Amount of tokens received from the position
    /// --------------------------------------------------------------------------------------------
    function closePosition(address _underlyingAsset, address _tokenReceiver, uint256 _amount) external virtual returns(uint256 _tokensReceived) {
        revert NotImplemented(_underlyingAsset, _tokenReceiver, _amount);
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Get the APY of the protocol connected to this adapter
    /// @dev Throw if the token address is zero or not a contract with error InvalidAddress()
    /// @dev Source calculation details: AAVE v2.0. 
    /// Website: https://docs.aave.com/developers/v/2.0/guides/apy-and-apr
    /// --------------------------------------------------------------------------------------------
    /// @param _token Token address of the underlying asset
    /// --------------------------------------------------------------------------------------------
    /// @return _depositAPY The APY of the protocol connected to this adapter
    /// --------------------------------------------------------------------------------------------
    function getDepositAPY(address _token) external view virtual returns(uint256 _depositAPY) {
        revert NotImplemented(_token, address(0), 0);
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
    error NotImplemented(address _token, address _user, uint256 _amount);
}