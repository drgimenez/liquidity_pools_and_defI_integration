//SPDX-License-Identifier:MIT
pragma solidity 0.8.21;

abstract contract Auth {

    /// STATE MAPPINGS

    /// @dev Owner index. Starts at 1.
    uint256 public ownerIndex;
    /// @dev owner address => bool
    mapping (address => bool) public owner;

    /// CONSTRUCTOR
    constructor (address _owner) {
            owner[_owner] = true;
    }

    /// EXTERNAL FUNCTIONS

    /// ---------------------------------------------------------------------------------------------
    /// @notice Add a new owner to the contract
    /// @dev Throw if the sender is not an owner with error NotAnOwner()
    /// @dev Throw if the owner address is zero with error ZeroAddress()
    /// --------------------------------------------------------------------------------------------
    /// @param _owner The address of the owner to add
    /// --------------------------------------------------------------------------------------------
    function addOwner(address _owner) external onlyOwner() isZeroAddress(_owner) {
        ownerIndex++;
        owner[_owner] = true;
        emit AddOwner(msg.sender, _owner);
    }

    /// ---------------------------------------------------------------------------------------------
    /// @notice Remove an owner from the contract
    /// @dev Throw if the sender is not an owner with error NotAnOwner()
    /// @dev Throw if the owner address is zero with error ZeroAddress()
    /// @dev Throw if the owner to remove is the last owner with error LastOwner()
    /// --------------------------------------------------------------------------------------------
    /// @param _owner The address of the owner to add
    /// --------------------------------------------------------------------------------------------
    function removeOwner(address _owner) external onlyOwner() isZeroAddress(_owner) isNotLastOwner() {
        ownerIndex--;
        delete owner[_owner];
        emit RemoveOwner(msg.sender, _owner);
    }

    /// MODIFIERS
    modifier onlyOwner() {
        if (!owner[msg.sender]) revert NotAnOwner(msg.sender);
        _;
    }

    modifier isZeroAddress(address _address) {
        if (_address == address(0)) revert ZeroAddress();
        _;
    }

    modifier isNotLastOwner() {
        if (ownerIndex == 1) revert LastOwner();
        _;
    }
    
    /// ERRROS
    error ZeroAddress();
    error ZeroAmount();
    error LastOwner();
    error NotAnOwner(address _sender);

    /// EVENTS
    event AddOwner(address indexed _owner, address indexed _newOwner);
    event RemoveOwner(address indexed _owner, address indexed _removedOwner);
}