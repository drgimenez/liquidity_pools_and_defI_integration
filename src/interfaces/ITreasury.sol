//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ITreasury {

    /// Structs types
    
    /// @notice Structure that represents the state of each ERC20 token supported by the protocol.
    struct Currency {
        IERC20 token;   // ERC20 token interface
        string name;    // ERC20 token name or symbol
        bool isActive;  // Is the ERC20 token supported by the protocol?
    }

    /// @notice Structure that represents the state of each protocol integrated into this protocol.
    struct Protocol {
        uint256 percentage;         // Percentage of the investment to be allocated to the protocol
        address protocolAddress;    // Contract address, main entry to the protocol interface.
        address adapterAddress;     // Address of the adapter contract that connects the protocol to this contract
        string name;                // Name of the protocol
        bool isActive;              // Is the protocol supported by the protocol?
    }

    /// Administrative functions

    /// ---------------------------------------------------------------------------------------------
    /// @notice Add a new ERC20 token that is supported by the protocol
    /// @dev Thhrow if the sender is not the owner with error NotAnOwner()
    /// @dev Throw if the token address is zero with error ZeroAddress()
    /// --------------------------------------------------------------------------------------------
    /// @param _name The name of the ERC20 token to add
    /// @param _token The address of the ERC20 token to add
    /// --------------------------------------------------------------------------------------------
    function addCurrency(string memory _name, IERC20 _token) external;
    
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
    function addProtocol(string memory _name, address _protocol, address _adapter, uint256 _percentage) external;

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
    function updateProtocol(uint256 _protocolIndex, string memory _name, address _protocol, address _adapter, uint256 _percentage) external;

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
    function invest(uint256 _currencyIndex, uint256 _amount) external;

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
    function withdraw(uint256 _protocolIndex, uint256 _currencyIndex, uint256 _amountToWithdraw) external;

    /// ---------------------------------------------------------------------------------------------
    /// @notice Calculate the aggregate percentage return of a given ERC20 token invested in connected 
    /// protocols 
    /// @dev Throw if the currency is not supported with error CurrencyNotSupported()
    /// @dev Source calculation details: AAVE v2.0 
    /// Website: https://docs.aave.com/developers/v/2.0/guides/apy-and-apr
    /// --------------------------------------------------------------------------------------------
    /// @param _currencyIndex The ERC token identifier
    /// --------------------------------------------------------------------------------------------
    function  calculateAggregatedPercentageYield(uint256 _currencyIndex) external view returns(uint256 _aggregatedPercentageYield);

    /// Errors
 
    error NotAnInvestor(address _sender);
    error InvalidPercentage(uint256 _percentage);
    error CurrencyNotSupported(uint256 _tokenIndex);
    error ProtocolNotSupported(uint256 _protocolIndex);
    error TransferFailed(address _from, address _to, uint256 _amount);
    error TransferTokenFailed(string _tokenSymbol, address _sender, uint256 _amount);
    error InsufficientAllowance(string _tokenSymbol, address _sender, uint256 _amount);
    error InvalidAmountToWithdraw(string _protocolName, address _sender, uint256 _amountToWithdraw);
    error WithdrawAmountIssue(string _protocolName, address _tokenReceiver, uint256 _amountToWithdraw, uint256 _withdrawnTokens);
}