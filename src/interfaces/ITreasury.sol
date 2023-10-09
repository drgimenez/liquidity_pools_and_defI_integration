//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ITreasury {

    /// Structs types
    
    struct Currency {
        IERC20 token;
        string name;
        bool isActive;
    }

    struct Protocol {
        uint256 percentage;
        address protocolAddress;
        address adapterAddress;
        string name;
        bool isActive;
    }

    /// Errors
    error InvalidPercentage(uint256 _percentage);
    error CurrencyNotSupported(uint256 _tokenIndex);
    error ProtocolNotSupported(uint256 _protocolIndex);
    error depositFailed(string _tokenSymbol, address _sender, uint256 _amount);
    error InsufficientAllowance(string _tokenSymbol, address _sender, uint256 _amount);
}