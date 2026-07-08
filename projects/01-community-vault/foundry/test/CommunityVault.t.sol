// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {CommunityVault} from "../src/CommunityVault.sol";

// helper contracts to tests
contract RejectETH {
    // Without receive() or fallback() → rejects ETH
}

// helper contracts to tests

contract RejectETHContributor {
    CommunityVault vault;
    constructor(CommunityVault v) { vault = v; }

    function doContribute() external payable {
        vault.contribute{value: msg.value}();
    }

    function doRefund() external {
        vault.refund();
    }
    // Without receive() → rejects ETH from refund
}

contract CommunityVaultTest is Test {
    // Constants
    uint256 constant GOAL = 1 ether;
    uint256 constant DURATION = 7 days;

    // States
    CommunityVault vault;
    address alice;
    address bob;

    // Setup
    function setUp() external {
        vault = new CommunityVault(GOAL, block.timestamp + DURATION, address(this));

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    // =========================================================================
    // Constructor
    // =========================================================================
    function test_RevertWhen_ConstructorGoalIsZero() external {
        vm.expectRevert(CommunityVault.InvalidGoal.selector);
        new CommunityVault(0, block.timestamp + DURATION, address(this));
    }

    function test_RevertWhen_ConstructorDeadlineInPast() external {
        vm.expectRevert(CommunityVault.InvalidDeadline.selector);
        new CommunityVault(GOAL, block.timestamp, address(this)); // deadline == now, not strictly after
    }

    function test_RevertWhen_ConstructorDeadlineStrictlyInPast() external {
        vm.expectRevert(CommunityVault.InvalidDeadline.selector);
        new CommunityVault(GOAL, block.timestamp - 1, address(this));
    }

    function test_RevertWhen_ConstructorInitialOwnerIsZero() external {
        // OZ v5 Ownable reverts before our custom logic runs
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new CommunityVault(GOAL, block.timestamp + DURATION, address(0));
    }



    // =========================================================================
    // Contributions
    // =========================================================================

    function test_ContributeMintsTokens() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        assertEq(vault.balanceOf(alice), 0.5 ether);
    }

    function test_ContributeRecordsContribution() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        assertEq(vault.contributions(alice), 0.5 ether);
    }

    function test_ContributeAccumulatesMultiple() external {
        vm.prank(alice);
        vault.contribute{value: 0.3 ether}();

        vm.prank(alice);
        vault.contribute{value: 0.4 ether}();

        // Verify token balance accumulates — 0.3 + 0.4 = 0.7 ether
        assertEq(vault.balanceOf(alice), 0.7 ether);
    }

    function test_ContributeAccumulatesContributionsMapping() external {
        vm.prank(alice);
        vault.contribute{value: 0.3 ether}();

        vm.prank(alice);
        vault.contribute{value: 0.4 ether}();

        assertEq(vault.contributions(alice), 0.7 ether);
    }

    function test_RevertWhen_ContributeAfterDeadline() external {
        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert(CommunityVault.DeadlineReached.selector);
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();
    }

    function test_RevertWhen_ContributeZeroValue() external {
        vm.expectRevert(CommunityVault.ZeroContribution.selector);
        vm.prank(alice);
        vault.contribute{value: 0}();
    }

    // =========================================================================
    // Withdrawal
    // =========================================================================

    function test_OwnerWithdrawsAfterGoalMet() external {
        vm.prank(alice);
        vault.contribute{value: GOAL}();

        vm.warp(block.timestamp + DURATION + 1);

        uint256 ownerBalanceBefore = address(this).balance;
        vault.withdraw();

        assertEq(address(this).balance, ownerBalanceBefore + GOAL);
    }

    function test_WithdrawEmptiesContractBalance() external {
        vm.prank(alice);
        vault.contribute{value: GOAL}();

        vm.warp(block.timestamp + DURATION + 1);
        vault.withdraw();

        assertEq(address(vault).balance, 0);
    }

    function test_RevertWhen_WithdrawGoalNotMet() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert(CommunityVault.GoalNotMet.selector);
        vault.withdraw();
    }

    function test_RevertWhen_WithdrawBeforeDeadline() external {
        vm.prank(alice);
        vault.contribute{value: GOAL}();

        // Do NOT warp — deadline has not passed yet.
        vm.expectRevert(CommunityVault.DeadlineNotReached.selector);
        vault.withdraw();
    }

    function test_RevertWhen_WithdrawCalledByNonOwner() external {
        vm.prank(alice);
        vault.contribute{value: GOAL}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert();
        vm.prank(bob);
        vault.withdraw();
    }

    function test_RevertWhen_WithdrawTransferFails() external {
        RejectETH rejecter = new RejectETH();
        CommunityVault v = new CommunityVault(GOAL, block.timestamp + DURATION, address(rejecter));

        vm.prank(alice);
        v.contribute{value: GOAL}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert(CommunityVault.TransferFailed.selector);
        vm.prank(address(rejecter)); // onlyOwner
        v.withdraw();
    }

    // =========================================================================
    // Refunds
    // =========================================================================

    function test_RefundReturnsFunds() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        vm.warp(block.timestamp + DURATION + 1);

        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        vault.refund();

        assertEq(alice.balance, aliceBalanceBefore + 0.5 ether);
    }

    function test_RefundBurnsTokens() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(alice);
        vault.refund();

        assertEq(vault.balanceOf(alice), 0);
    }

    function test_RefundZerosContribution() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(alice);
        vault.refund();

        assertEq(vault.contributions(alice), 0);
    }

    function test_RevertWhen_RefundBeforeDeadline() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        vm.expectRevert(CommunityVault.DeadlineNotReached.selector);
        vm.prank(alice);
        vault.refund();
    }

    function test_RevertWhen_RefundGoalWasMet() external {
        vm.prank(alice);
        vault.contribute{value: GOAL}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert(CommunityVault.GoalAlreadyMet.selector);
        vm.prank(alice);
        vault.refund();
    }

    function test_RevertWhen_DoubleRefund() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(alice);
        vault.refund();

        // Second call must revert because contributions[alice] is now 0.
        vm.expectRevert(CommunityVault.NoContributionFound.selector);
        vm.prank(alice);
        vault.refund();
    }

    function test_RevertWhen_RefundTransferFails() external {
        RejectETHContributor attacker = new RejectETHContributor(vault);
        vm.deal(address(attacker), 0.5 ether);

        attacker.doContribute{value: 0.5 ether}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert(CommunityVault.TransferFailed.selector);
        attacker.doRefund();
    }

    // =========================================================================
    // Events
    // =========================================================================

    function test_EmitsContributionReceived() external {
        // topic1 = contributor (indexed), data = amount
        vm.expectEmit(true, false, false, true);
        emit CommunityVault.ContributionReceived(alice, 0.5 ether);

        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();
    }

    function test_EmitsFundsWithdrawn() external {
        vm.prank(alice);
        vault.contribute{value: GOAL}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectEmit(true, false, false, true);
        emit CommunityVault.FundsWithdrawn(address(this), GOAL);

        vault.withdraw();
    }

    function test_EmitsRefundClaimed() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectEmit(true, false, false, true);
        emit CommunityVault.RefundClaimed(alice, 0.5 ether);

        vm.prank(alice);
        vault.refund();
    }

    // =========================================================================
    // getStatus
    // =========================================================================

    function test_StatusIsActiveBeforeDeadline() external view {
        assertEq(uint256(vault.getStatus()), uint256(CommunityVault.Status.Active));
    }

    function test_StatusIsSuccessfulAfterGoalMet() external {
        vm.prank(alice);
        vault.contribute{value: GOAL}();

        vm.warp(block.timestamp + DURATION + 1);

        assertEq(uint256(vault.getStatus()), uint256(CommunityVault.Status.Successful));
    }

    function test_StatusIsFailedAfterDeadlineMissed() external {
        vm.prank(alice);
        vault.contribute{value: 0.5 ether}();

        vm.warp(block.timestamp + DURATION + 1);

        assertEq(uint256(vault.getStatus()), uint256(CommunityVault.Status.Failed));
    }

    // =========================================================================
    // Fuzz
    // =========================================================================

    /// @notice Invariant: the sum of legitimate refund claims can never exceed
    ///         the contract's ETH balance, ensuring no over-withdrawal is possible.
    function testFuzz_RefundsNeverExceedContractBalance(
        uint96 amountAlice,
        uint96 amountBob
    ) external {
        // Bound both amounts to [1, goal/2 - 1] so their sum never reaches goal,
        // which keeps the campaign in Failed state and allows refunds.
        uint256 halfGoal = GOAL / 2;
        uint256 a = bound(uint256(amountAlice), 1, halfGoal - 1);
        uint256 b = bound(uint256(amountBob), 1, halfGoal - 1);

        vm.deal(alice, a);
        vm.deal(bob, b);

        vm.prank(alice);
        vault.contribute{value: a}();

        vm.prank(bob);
        vault.contribute{value: b}();

        vm.warp(block.timestamp + DURATION + 1);

        uint256 aliceBalanceBefore = alice.balance;
        uint256 bobBalanceBefore = bob.balance;

        vm.prank(alice);
        vault.refund();

        vm.prank(bob);
        vault.refund();

        // The contract must be fully drained — no ETH stranded, no over-withdrawal.
        assertEq(address(vault).balance, 0);

        // Each contributor gets back exactly what they put in.
        assertEq(alice.balance, aliceBalanceBefore + a);
        assertEq(bob.balance, bobBalanceBefore + b);
    }

    // -------------------------------------------------------------------------
    // Receive ETH (needed so address(this) can accept the owner withdrawal)
    // -------------------------------------------------------------------------

    receive() external payable {}
}
