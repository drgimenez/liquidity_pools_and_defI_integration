//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "src/abstracts/Adapter.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice AAVE adapter to connect to the AAVE protocol
/// @dev Inheritance: Adapter -> Auth -> ReentrancyGuard
contract AAVE_Adapter is Adapter {

    /// State variables
    /// @notice Address of the AAVE pool
    IPool public pool;

    /// @notice Initialize the AAVE adapter
    /// @dev Throw if the pool address is zero or not a contract with error InvalidAddress()
    /// @param _pool Address of the AAVE pool
    constructor(IPool _pool) Adapter() isValidAddress(address(_pool)) {
        pool = _pool;
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Open a position in the protocol connected to this adapter
    /// @dev Implement non-reentry with OpenZeppelin's ReentrancyGuard
    /// @dev Throw if the sender is not an owner with error NotAnOwner(). The treasury contract is an owner.
    /// @dev Throw if the token address is zero or not a contract with error InvalidAddress()
    /// @dev Throw if the token receiver address is zero or not a contract with error InvalidAddress()
    /// @dev Throw if the amount is zero with error ZeroAmount()
    /// --------------------------------------------------------------------------------------------
    /// @param _token Address of the underlying asset token used to open the positions
    /// @param _tokenReceiver Address of the account that will receive the tokens provided by the 
    /// protocol connected to this adapter
    /// @param _amount Amount of tokens to open the position
    /// --------------------------------------------------------------------------------------------
    /// @return _success True if the position was opened successfully
    /// --------------------------------------------------------------------------------------------
    function openPosition(address _token, address _tokenReceiver, uint256 _amount) external override
    nonReentrant() 
    onlyOwner()
    isValidAddress(_token)
    isValidAddress(_tokenReceiver)
    isZeroAmount(_amount)
    returns(bool _success)
    {
        _success = _approveLiquidity(_token, _amount);
        _success = _supplyLiquidity(_token, _tokenReceiver, _amount);
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Close a position in the protocol connected to this adapter
    /// @dev Implement non-reentry with OpenZeppelin's ReentrancyGuard
    /// @dev Throw if the sender is not an owner with error NotAnOwner(). The treasury contract is an owner.
    /// @dev Throw if the token address is zero or not a contract with error InvalidAddress()
    /// @dev Throw if the token receiver address is zero or not a contract with error InvalidAddress()
    /// @dev Throw if the amount is zero with error ZeroAmount()
    /// --------------------------------------------------------------------------------------------
    /// @param _token Token address of the underlying asset used to open the positions to be closed
    /// @param _tokenReceiver Address of the account that will receive the withdrawn tokens 
    /// @param _amount Amount of tokens to withdraw from the position
    /// --------------------------------------------------------------------------------------------
    /// @return _tokensReceived Amount of tokens received from the position
    /// --------------------------------------------------------------------------------------------
    function closePosition(address _token, address _tokenReceiver, uint256 _amount) external override 
    nonReentrant() 
    onlyOwner()
    isValidAddress(_token)
    isZeroAddress(_tokenReceiver)
    isZeroAmount(_amount)
    returns(uint256 _tokensReceived) 
    {
        _tokensReceived = _withdrawLiquidity(_token, _tokenReceiver, _amount);
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
    function getDepositAPY(address _token) external view override isValidAddress(_token) returns(uint256 _depositAPY) {
        uint256 SECONDS_PER_YEAR = 31536000;
        DataTypes.ReserveData memory _reserveData = pool.getReserveData(_token);
        uint256 _depositAPR = _reserveData.currentLiquidityRate / 1e9; // Remove 9 decimals to become 18 decimals number
        _depositAPY = ((1 ether + ((_depositAPR / SECONDS_PER_YEAR) * 1e8)) ^ SECONDS_PER_YEAR) - 1 ether;
    }

    /// Internal Functions

    function _approveLiquidity(address _token, uint256 _amount) internal returns(bool _success) {
        try IERC20(_token).approve(address(pool), _amount) {
            _success = true;
        }
        catch Error(string memory _errorMessage) {
            revert(_errorMessage);
        }
    }

    function _supplyLiquidity(address _token, address _tokenReceiver, uint256 _amount) internal returns(bool _success) {
        // Call supply in the pool
        address _asset = _token; 
        address _onBehalfOf = _tokenReceiver; 
        uint16 _referralCode = 0;
        try pool.supply(_asset, _amount, _onBehalfOf, _referralCode) {
            _success = true;
        }
        catch Error(string memory _errorMessage) {
            revert(_errorMessage);
        }
    }

    function _withdrawLiquidity(address _token, address _tokenReceiver, uint256 _amount) internal returns(uint256 _tokensReceived) {
        // Call withdraw in the pool
        address _asset = _token; 
        address _to = _tokenReceiver;

        try pool.withdraw(_asset, _amount, _to) returns(uint256 _tokensAmount) {
            _tokensReceived = _tokensAmount;
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
