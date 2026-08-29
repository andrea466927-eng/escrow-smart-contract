// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Escrow
 * @dev A secure escrow contract for holding funds between buyer and seller
 * @notice This contract manages the complete lifecycle of an escrow transaction
 */

contract Escrow {
    // State variables
    address public buyer;
    address public seller;
    address public arbitrator;
    uint256 public amount;
    uint256 public deadline;
    bool public isDisputed;
    bool public isReleased;
    bool public isRefunded;
    bool public isPaused;
    address public owner;

    // Enum for dispute resolution
    enum DisputeStatus {
        NONE,
        PENDING,
        RESOLVED_FOR_BUYER,
        RESOLVED_FOR_SELLER
    }

    DisputeStatus public disputeStatus;

    // Events
    event Deposited(
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        uint256 deadline
    );
    event DeliveryApproved(address indexed buyer, uint256 amount);
    event RefundInitiated(address indexed seller, uint256 amount);
    event RefundApproved(address indexed buyer, uint256 amount);
    event DisputeRaised(address indexed raiser, string reason);
    event DisputeResolved(
        DisputeStatus status,
        address indexed arbitrator,
        string reason
    );
    event FundsReleased(address indexed recipient, uint256 amount);
    event ContractPaused(address indexed owner);
    event ContractUnpaused(address indexed owner);

    // Modifiers
    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this");
        _;
    }

    modifier onlyArbitrator() {
        require(msg.sender == arbitrator, "Only arbitrator can call this");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }

    modifier notReleased() {
        require(!isReleased && !isRefunded, "Escrow already finalized");
        _;
    }

    /**
     * @dev Initialize escrow contract
     * @param _buyer Address of the buyer
     * @param _seller Address of the seller
     * @param _arbitrator Address of the arbitrator (can be zero address)
     * @param _amount Amount to be held in escrow (in wei)
     * @param _duration Duration in seconds until automatic refund
     */
    constructor(
        address _buyer,
        address _seller,
        address _arbitrator,
        uint256 _amount,
        uint256 _duration
    ) {
        require(_buyer != address(0), "Invalid buyer address");
        require(_seller != address(0), "Invalid seller address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        buyer = _buyer;
        seller = _seller;
        arbitrator = _arbitrator;
        amount = _amount;
        deadline = block.timestamp + _duration;
        owner = msg.sender;
        isDisputed = false;
        isReleased = false;
        isRefunded = false;
        isPaused = false;
        disputeStatus = DisputeStatus.NONE;
    }

    /**
     * @dev Deposit funds into escrow (called by buyer)
     */
    function deposit() external payable onlyBuyer notPaused notReleased {
        require(msg.value == amount, "Incorrect deposit amount");
        require(block.timestamp < deadline, "Deadline passed");

        emit Deposited(buyer, seller, amount, deadline);
    }

    /**
     * @dev Buyer approves delivery and releases funds to seller
     */
    function approveDelivery() external onlyBuyer notPaused notReleased {
        require(!isDisputed, "Cannot approve while disputed");
        require(address(this).balance >= amount, "Insufficient balance");

        isReleased = true;

        // Transfer funds to seller
        (bool success, ) = seller.call{value: amount}("");
        require(success, "Transfer failed");

        emit DeliveryApproved(buyer, amount);
        emit FundsReleased(seller, amount);
    }

    /**
     * @dev Seller initiates refund to buyer
     */
    function refund() external onlySeller notPaused notReleased {
        require(!isDisputed, "Cannot refund while disputed");
        require(address(this).balance >= amount, "Insufficient balance");

        isRefunded = true;

        // Transfer funds back to buyer
        (bool success, ) = buyer.call{value: amount}("");
        require(success, "Transfer failed");

        emit RefundInitiated(seller, amount);
        emit FundsReleased(buyer, amount);
    }

    /**
     * @dev Raise a dispute (called by buyer or seller)
     * @param reason Reason for the dispute
     */
    function raiseDispute(string memory reason)
        external
        notPaused
        notReleased
    {
        require(
            msg.sender == buyer || msg.sender == seller,
            "Only buyer or seller can raise dispute"
        );
        require(!isDisputed, "Dispute already raised");
        require(arbitrator != address(0), "No arbitrator assigned");

        isDisputed = true;
        disputeStatus = DisputeStatus.PENDING;

        emit DisputeRaised(msg.sender, reason);
    }

    /**
     * @dev Resolve dispute (called by arbitrator)
     * @param favorizeBuyer True if funds go to buyer, false if to seller
     * @param reason Reason for resolution
     */
    function resolveDispute(bool favorizeBuyer, string memory reason)
        external
        onlyArbitrator
        notPaused
        notReleased
    {
        require(isDisputed, "No dispute to resolve");
        require(
            disputeStatus == DisputeStatus.PENDING,
            "Dispute already resolved"
        );
        require(address(this).balance >= amount, "Insufficient balance");

        address recipient = favorizeBuyer ? buyer : seller;
        DisputeStatus status = favorizeBuyer
            ? DisputeStatus.RESOLVED_FOR_BUYER
            : DisputeStatus.RESOLVED_FOR_SELLER;

        disputeStatus = status;
        isReleased = true;

        // Transfer funds to recipient
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");

        emit DisputeResolved(status, msg.sender, reason);
        emit FundsReleased(recipient, amount);
    }

    /**
     * @dev Emergency refund after deadline if no action taken
     */
    function emergencyRefund() external notPaused notReleased {
        require(block.timestamp >= deadline, "Deadline not yet reached");
        require(!isDisputed, "Cannot refund disputed escrow");
        require(address(this).balance >= amount, "Insufficient balance");

        isRefunded = true;

        // Return funds to buyer
        (bool success, ) = buyer.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsReleased(buyer, amount);
    }

    /**
     * @dev Pause contract (emergency function)
     */
    function pause() external onlyOwner {
        isPaused = true;
        emit ContractPaused(owner);
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        isPaused = false;
        emit ContractUnpaused(owner);
    }

    /**
     * @dev Get escrow status details
     */
    function getStatus()
        external
        view
        returns (
            address,
            address,
            address,
            uint256,
            uint256,
            bool,
            bool,
            bool,
            DisputeStatus
        )
    {
        return (
            buyer,
            seller,
            arbitrator,
            amount,
            deadline,
            isDisputed,
            isReleased,
            isRefunded,
            disputeStatus
        );
    }

    /**
     * @dev Get remaining time until deadline
     */
    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    /**
     * @dev Get current balance of escrow
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Receive ETH transfers
     */
    receive() external payable {}

    /**
     * @dev Fallback function
     */
    fallback() external payable {}
}
