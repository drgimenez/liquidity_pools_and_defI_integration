//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "src/interfaces/ITreasury.sol";
import "src/context/Auth.sol";
import "hardhat/console.sol";

contract Treasury is Auth, ReentrancyGuard, ITreasury {

    /// State Variables
    uint256 public protocolIndex;
    uint256 public currencyIndex;
    
    /// Mappings
    /// @dev Currency index => { IERC20 token, token name, is active? }
    mapping(uint256 => Currency) public currency;
    /// @dev protocol index => { protocol percentage, protocol address, adapter address, protocol name, is active? }
    mapping(uint256 => Protocol) public protocol;
    /// @dev protocol name => owner address => balance
    mapping(string => mapping(address => uint256)) public balanceOf;   
    
    //inversionOf;

    /// Constructor
    constructor() Auth(msg.sender) {}

    /// Administrative functions

    function addCurrency(string memory _name, IERC20 _token) external 
    onlyOwner() 
    isZeroAddress(address(_token)) 
    {
        currencyIndex++;
        currency[currencyIndex] = Currency(_token, _name, true);
    }

    function addProtocol(string memory _name, address _protocol, address _adapter, uint256 _percentage) external 
    onlyOwner() 
    isZeroAddress(_protocol) 
    {
        protocolIndex++;
        protocol[protocolIndex] = Protocol(_percentage, _protocol, _adapter, _name, true);
    }

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

    function deposit(uint256 _currencyIndex, uint256 _amount) external 
    nonReentrant() 
    isZeroAmount(_amount) 
    isCurrencySupported(_currencyIndex)
    hasAllowance(_currencyIndex, _amount)
    returns(bool _success) 
    {   
        Currency memory _currency = currency[_currencyIndex];
        IERC20 _token = _currency.token;
        balanceOf[_currency.name][msg.sender] += _amount;
        _success = _token.transferFrom(msg.sender, address(this), _amount);
        if (!_success) revert depositFailed(_currency.name, msg.sender, _amount);
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