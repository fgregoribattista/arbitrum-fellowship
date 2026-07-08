// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CommunityVault contract 
/// TODO: see what happens with block.timestamp in comparison (can be manipulated)
/// @notice A crowdfunding vault that emits ERC-20 tokens proportional to ETH contributions.
///         If the campaign meets its goal by the deadline, the owner can withdraw funds.
///         If it fails, contributors can reclaim their ETH and burn their tokens.
/// @dev    This contract use OpenZeppelin v5 Ownable and ReentrancyGuard, and v4 ERC20. It is designed to be deployed with a non-zero goal and a future deadline.

contract CommunityVault is ERC20, Ownable, ReentrancyGuard {
    // Errors 
    error DeadlineNotReached();
    error DeadlineReached();
    error GoalNotMet();
    error GoalAlreadyMet();
    error ZeroContribution();
    error NoContributionFound();
    error InvalidGoal();
    error InvalidDeadline();
    error TransferFailed();

    // Events
    event ContributionReceived(address indexed contributor, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event RefundClaimed(address indexed contributor, uint256 amount);

    // States
    enum Status {
        Active,
        Successful,
        Failed
    }

    /// @dev Funding target expressed in wei.
    uint256 public immutable goal;

    /// @dev The deadline for the campaign, expressed as a unix timestamp.
    uint256 public immutable deadline;

    /// @dev sum of all ETH contributed
    uint256 public totalContributed;

    /// @dev Per-address ETH contribution in wei.
    mapping(address => uint256) public contributions;


    /// @notice create the contract with a funding goal and deadline.
    /// @dev    The constructor validates the goal and deadline to create a valid contract
    /// @param goal_         Funding goal in wei. Must be > 0.
    /// @param deadline_     Unix timestamp. Must be strictly after block.timestamp.
    /// @param initialOwner  Passed directly to OZ Ownable v5 — sets the initial owner. Must be a non-zero address.
    // TODO: Consider adding the name and symbol as constructor parameters to make the contract more flexible for tokens with different branding.
    constructor(uint256 goal_, uint256 deadline_, address initialOwner)
        ERC20("Community Vault Token", "CVT")
        Ownable(initialOwner)
    {
        // Validate at the system boundary (initialOwner is validated in OZ Ownable v5)
        if (goal_ == 0) revert InvalidGoal();
        if (deadline_ <= block.timestamp) revert InvalidDeadline();

        goal = goal_;
        deadline = deadline_;
    }

    /// @notice Contribute ETH to the campaign. Mints an equal amount of CVT tokens to the caller (1 wei = 1 CVT).
    /// @dev Validates that the campaign is still active and that the contribution is non-zero. Mints tokens and emits ContributionReceived event.
    ///     Can revert if the deadline is reached. DeadlineReached error
    ///     Can revert if the contribution is zero. ZeroContribution error
    function contribute() external payable nonReentrant {
        // Validates
        if (block.timestamp >= deadline) revert DeadlineReached();
        if (msg.value == 0) revert ZeroContribution();

        // Update states
        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;

        // Mint tokens 
        _mint(msg.sender, msg.value);

        emit ContributionReceived(msg.sender, msg.value);
    }

    /// @notice Withdraw all ETH to the owner once the campaign has succeeded.
    /// @dev Validates that the campaign has ended and that the goal was met. Emit FundsWithdrawn event, and transfers all ETH to the owner.
    /// @custom:error TransferFailed if the transfer fails.
    /// @custom:error DeadlineNotReached if the deadline is not reached.
    /// @custom:error GoalNotMet if the goal is not met.
    function withdraw() external onlyOwner nonReentrant {
        // Validates
        if (block.timestamp < deadline) revert DeadlineNotReached();
        if (totalContributed < goal) revert GoalNotMet();

        // Take balance of the contract
        uint256 amount = address(this).balance;

        emit FundsWithdrawn(owner(), amount);

        // Try to transfer the funds to the owner. If it fails, revert the transaction.
        (bool success,) = owner().call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Reclaim ETH when the campaign has failed. Burns the caller's CVT tokens before transferring ETH (CEI).
    /// @dev Validates that the campaign has ended and that the goal was not met. Emit RefundClaimed event, and transfers ETH to the caller.
    /// @custom:error TransferFailed if the transfer fails.
    /// @custom:error DeadlineNotReached if the deadline is not reached.
    /// @custom:error GoalAlreadyMet if the goal is already met.
    /// @custom:error NoContributionFound if no contribution is found.
    function refund() external nonReentrant {
        // Validates
        if (block.timestamp < deadline) revert DeadlineNotReached();
        if (totalContributed >= goal) revert GoalAlreadyMet();

        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert NoContributionFound();

        // Take balance of contributor sender, reset contributions to 0 and burn the tokens
        contributions[msg.sender] = 0;
        _burn(msg.sender, amount);

        emit RefundClaimed(msg.sender, amount);

        // Try to transfer the funds to the contributor. If it fails, revert the transaction.
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Returns the current campaign status.
    /// @dev    Returns Active if the deadline has not been reached, Successful if the goal has been met, and Failed otherwise.
    /// @return Status The current status of the campaign.
    function getStatus() external view returns (Status) {
        if (block.timestamp < deadline) return Status.Active;
        if (totalContributed >= goal) return Status.Successful;
        return Status.Failed;
    }
}
