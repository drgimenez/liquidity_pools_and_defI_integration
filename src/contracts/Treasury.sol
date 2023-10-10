//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "src/interfaces/ITreasury.sol";
import "src/context/Auth.sol";
import "src/abstracts/Adapter.sol";

contract Treasury is Auth, ReentrancyGuard, ITreasury {

    /// State Variables
    uint256 public protocolIndex;
    uint256 public currencyIndex;
    
    /// Mappings
    /// @dev Currency index => { IERC20 token, token name, is active? }
    mapping(uint256 => Currency) public currency;
    /// @dev protocol index => { protocol percentage, protocol address, adapter address, protocol name, is active? }
    mapping(uint256 => Protocol) public protocol;
    /// @dev token name => owner address => balance
    mapping(string => mapping(address => uint256)) public balanceOf;
    /// @dev protocol name => owner address => investAmount
    mapping(string => mapping(address => uint256)) public investOf;

    /// Constructor
    constructor() Auth(msg.sender) {}

    /// Administrative functions

    /// ---------------------------------------------------------------------------------------------
    /// @notice Add a new ERC20 token that is supported by the protocol
    /// @dev Throw if the sender is not an owner with error NotAnOwner()
    /// @dev Throw if the token address is zero with error ZeroAddress()
    /// --------------------------------------------------------------------------------------------
    /// @param _name The name of the ERC20 token to add
    /// @param _token The address of the ERC20 token to add
    /// --------------------------------------------------------------------------------------------
    function addCurrency(string memory _name, IERC20 _token) external 
    onlyOwner() 
    isZeroAddress(address(_token)) 
    {
        currencyIndex++;
        currency[currencyIndex] = Currency(_token, _name, true);
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Adds a new protocol that has been integrated into this protocol.
    /// @dev Throw if the sender is not an owner with error NotAnOwner()
    /// @dev Throw if the protocol address is zero with error ZeroAddress()
    /// @dev Throw if the percentage is zero or greater than 100 with error InvalidPercentage()
    /// --------------------------------------------------------------------------------------------
    /// @param _name The name of the protocol to connect to this protocol
    /// @param _protocol The address of the protocol to connect to this protocol
    /// @param _adapter The address of the adapter for the protocol to add. It can be address zero.
    /// @param _percentage The investment percentage for which protocol to add
    /// --------------------------------------------------------------------------------------------
    function addProtocol(string memory _name, address _protocol, address _adapter, uint256 _percentage) external 
    onlyOwner() 
    isZeroAddress(_protocol) 
    isValidPercentage(_percentage)
    {
        protocolIndex++;
        protocol[protocolIndex] = Protocol(_percentage, _protocol, _adapter, _name, true);
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Update the metadata of a protocol that has been integrated into this protocol.
    /// @dev Throw if the sender is not an owner with error NotAnOwner()
    /// @dev Throw if the protocol address is zero with error ZeroAddress()
    /// @dev Throw if the percentage is zero or greater than 100 with error InvalidPercentage()
    /// @dev Throw if the protocol address is not supported with error ProtocolNotSupported()
    /// --------------------------------------------------------------------------------------------
    /// @param _protocolIndex The identifier of the protocol to update.
    /// @param _name The name of the protocol to connect to this protocol
    /// @param _protocol The address of the protocol to connect to this protocol
    /// @param _adapter The address of the adapter for the protocol to add
    /// @param _percentage The investment percentage for which protocol to add
    /// --------------------------------------------------------------------------------------------
    function updateProtocol(uint256 _protocolIndex, string memory _name, address _protocol, address _adapter, uint256 _percentage) external 
    onlyOwner()
    isValidPercentage(_percentage)
    isZeroAddress(_protocol)
    isProtocolSupported(_protocolIndex)
    {
        delete protocol[protocolIndex];
        protocol[protocolIndex] = Protocol(_percentage, _protocol, _adapter, _name, true);
    }

    /// External functions

    /// ---------------------------------------------------------------------------------------------
    /// @notice Allows an investor to deposit funds into the protocol to invest in connected protocols
    /// @dev Implement non-reentry with OpenZeppelin's ReentrancyGuard
    /// @dev Throw if the amount is zero with error ZeroAmount()
    /// @dev Throw if the currency is not supported with error CurrencyNotSupported()
    /// @dev Throw if investor did not give enough allowance to this contract with error InsufficientAllowance()
    /// --------------------------------------------------------------------------------------------
    /// @param _currencyIndex The ERC token identifier for investing
    /// @param _amount The amount of ERC20 token to invest
    /// --------------------------------------------------------------------------------------------
    function invest(uint256 _currencyIndex, uint256 _amount) external 
    nonReentrant() 
    isZeroAmount(_amount) 
    isCurrencySupported(_currencyIndex)
    hasAllowance(_currencyIndex, _amount)
    {   
        _transferToken(_currencyIndex, _amount);
        _invest(_currencyIndex);
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Allows an investor to withdraw funds from the protocol
    /// @dev Implement non-reentry with OpenZeppelin's ReentrancyGuard
    /// @dev Throw if the amount is zero with error ZeroAmount()
    /// @dev Throw if the currency is not supported with error CurrencyNotSupported()
    /// @dev Throw if sender is not an investor with error NotAnInvestor()
    /// --------------------------------------------------------------------------------------------
    /// @param _protocolIndex The protocol identifier for withdrawing funds.
    /// @param _currencyIndex The ERC token identifier for withdrawing
    /// @param _amountToWithdraw The amount of ERC20 token to withdraw
    /// --------------------------------------------------------------------------------------------
    function withdraw(uint256 _protocolIndex, uint256 _currencyIndex, uint256 _amountToWithdraw) external
    nonReentrant()
    isZeroAmount(_amountToWithdraw) 
    isCurrencySupported(_currencyIndex)
    {
        Protocol memory _protocol = protocol[_protocolIndex];
        uint256 _amountInvested = investOf[_protocol.name][msg.sender];
        
        // Only investors
        if(_amountInvested == 0) revert NotAnInvestor(msg.sender);
        
        // If the amount to withdraw is greater than the amount invested, withdraw the total amount invested
        if (_amountToWithdraw > _amountInvested) {
            _amountToWithdraw = _amountInvested;
        }

        investOf[_protocol.name][msg.sender] -= _amountToWithdraw;

        address _underlyingAsset = address(currency[_currencyIndex].token);
        address _tokenReceiver = msg.sender;
        try Adapter(_protocol.adapterAddress).closePosition(_underlyingAsset, _tokenReceiver, _amountToWithdraw) returns(uint256 _withdrawnTokens) {
            if (_amountToWithdraw != _withdrawnTokens) revert WithdrawAmountIssue(_protocol.name, _tokenReceiver, _amountToWithdraw, _withdrawnTokens);
        }
        catch Error(string memory _errorMessage) {
            revert(_errorMessage);
        }
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Calculate the aggregate percentage return of a given ERC20 token invested in connected 
    /// protocols 
    /// @dev Throw if the currency is not supported with error CurrencyNotSupported()
    /// @dev Source calculation details: AAVE v2.0 
    /// Website: https://docs.aave.com/developers/v/2.0/guides/apy-and-apr
    /// --------------------------------------------------------------------------------------------
    /// @param _currencyIndex The ERC token identifier
    /// --------------------------------------------------------------------------------------------
    /// @return _aggregatedPercentageYield The aggregate percentage yield for all connected protocols
    /// --------------------------------------------------------------------------------------------
    function  calculateAggregatedPercentageYield(uint256 _currencyIndex) external view
    isCurrencySupported(_currencyIndex)
    returns(uint256 _aggregatedPercentageYield)
    {
        uint256 _presentValueTotal;
        uint256 _futureValueTotal;
        uint256 _presentValue;
        Protocol memory _protocol;
        Currency memory _currency = currency[_currencyIndex];
        
        uint256 _APY;
        uint256 _futurevalue;
        for(uint256 i = 1; i <= protocolIndex; i++) {
            _protocol = protocol[i];
            _presentValue = investOf[_protocol.name][msg.sender];

            if(_presentValue != 0) {
                _presentValue = _presentValue * 1e12; // To 18 decimals
                _APY = Adapter(_protocol.adapterAddress).getDepositAPY(address(_currency.token));
                //uint256 _periods = 1;
                _futurevalue = _presentValue * (1 ether + _APY) / 1 ether; // ** _periods;
                _presentValueTotal += _presentValue;
                _futureValueTotal += _futurevalue;
            }
        }

        if(_presentValueTotal > 0) {
            _aggregatedPercentageYield = ((_futureValueTotal * 1 ether / _presentValueTotal) - 1 ether) * 100;
        }
    } 

    /// Internal functions

    function _transferToken(uint256 _currencyIndex, uint256 _amount) internal returns(bool _success) {
        Currency memory _currency = currency[_currencyIndex];
        IERC20 _token = _currency.token;
        balanceOf[_currency.name][msg.sender] += _amount;
        _success = _token.transferFrom(msg.sender, address(this), _amount);
        if (!_success) revert TransferTokenFailed(_currency.name, msg.sender, _amount);
    }

    function _invest(uint256 _currencyIndex) internal returns(bool _success){
        Currency memory _currency = currency[_currencyIndex];
        IERC20 _token = _currency.token;
        uint256 _amount = balanceOf[_currency.name][msg.sender];

        // OpenPosition variables
        address _underlyingAsset = address(_token);

        Protocol memory _protocol;
        uint256 _amountToInvest;
        for(uint256 i = 1; i <= protocolIndex; i++) {
            _protocol = protocol[i];
            _amountToInvest = (_amount * _protocol.percentage) / 100;

            balanceOf[_currency.name][msg.sender] -= _amountToInvest;
            investOf[_protocol.name][msg.sender] += _amountToInvest;

            _success = _token.transfer(_protocol.adapterAddress, _amountToInvest);       
            if(!_success) revert TransferFailed(address(this), address(_protocol.adapterAddress), _amountToInvest);

            address _tokenReceiver = _protocol.adapterAddress;
            try Adapter(_protocol.adapterAddress).openPosition(_underlyingAsset, _tokenReceiver, _amountToInvest) {
                return true;
            }
            catch Error(string memory _errorMessage) {
                revert(_errorMessage);
            }
        }
    }

    /// Modifiers
    modifier isZeroAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    modifier isCurrencySupported(uint256 _currencyIndex) {
        if (address(currency[_currencyIndex].token) == address(0)) revert CurrencyNotSupported(_currencyIndex);
        _;
    }

    modifier isProtocolSupported(uint256 _protocolIndex) {
        if (protocol[_protocolIndex].protocolAddress == address(0)) revert ProtocolNotSupported(_protocolIndex);
        _;
    }

    modifier hasAllowance(uint256 _currencyIndex, uint256 _amount) {
        Currency memory _currenty = currency[_currencyIndex];
        IERC20 _token = _currenty.token;
        if(_token.allowance(msg.sender, address(this)) < _amount) revert InsufficientAllowance(_currenty.name, msg.sender, _amount);
        _;
    }

    modifier isValidPercentage(uint256 _percentage) {
        if (_percentage == 0 || _percentage > 100) revert InvalidPercentage(_percentage);
        _;
    }
}