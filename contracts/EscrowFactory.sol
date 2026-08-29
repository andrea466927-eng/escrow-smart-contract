// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Escrow.sol";

/**
 * @title EscrowFactory
 * @dev Factory contract for creating and managing escrow instances
 */

contract EscrowFactory {
    address[] public escrows;
    mapping(address => address[]) public userEscrows;
    address public owner;

    event EscrowCreated(
        address indexed escrowAddress,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        uint256 deadline
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Create a new escrow contract
     * @param _buyer Address of the buyer
     * @param _seller Address of the seller
     * @param _arbitrator Address of the arbitrator
     * @param _amount Amount to hold in escrow
     * @param _duration Duration until automatic refund
     * @return Address of the created escrow contract
     */
    function createEscrow(
        address _buyer,
        address _seller,
        address _arbitrator,
        uint256 _amount,
        uint256 _duration
    ) external returns (address) {
        Escrow newEscrow = new Escrow(
            _buyer,
            _seller,
            _arbitrator,
            _amount,
            _duration
        );

        address escrowAddress = address(newEscrow);
        escrows.push(escrowAddress);
        userEscrows[_buyer].push(escrowAddress);
        userEscrows[_seller].push(escrowAddress);

        emit EscrowCreated(
            escrowAddress,
            _buyer,
            _seller,
            _amount,
            block.timestamp + _duration
        );

        return escrowAddress;
    }

    /**
     * @dev Get total number of escrows created
     */
    function getEscrowCount() external view returns (uint256) {
        return escrows.length;
    }

    /**
     * @dev Get escrow address by index
     */
    function getEscrowByIndex(uint256 index)
        external
        view
        returns (address)
    {
        require(index < escrows.length, "Index out of bounds");
        return escrows[index];
    }

    /**
     * @dev Get all escrows for a user
     */
    function getUserEscrows(address user)
        external
        view
        returns (address[] memory)
    {
        return userEscrows[user];
    }

    /**
     * @dev Get number of escrows for a user
     */
    function getUserEscrowCount(address user)
        external
        view
        returns (uint256)
    {
        return userEscrows[user].length;
    }
}
