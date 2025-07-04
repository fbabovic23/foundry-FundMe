//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("user");
    uint256 constant INTERNAL_AMOUNT = 10e18;
    uint256 constant STARTING_BALANCE = 100e18;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testIsMinimalUsd() public view {
        assertEq(fundMe.MINIMUM_USD(), 5 * 10 ** 18);
    }

    //when checking i_owner==msg.sender, there is an error because it goes us->FundMeTest->FundMe, so test is deploying, and it is msg,scanner5 * 10 ** 18;
    function testOwner() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionAccurate() public view {
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert();
        fundMe.fund();
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: INTERNAL_AMOUNT}();
        _;
    }

    function testFundUpdatesDataStructures() public {
        vm.prank(USER);
        fundMe.fund{value: INTERNAL_AMOUNT}();

        uint256 amountFunded = fundMe.getAddressToAmount(USER);
        assertEq(amountFunded, INTERNAL_AMOUNT);
    }

    function testAddsFundersToArrayOfFunders() public funded {
        address funder = fundMe.getFunders(0);
        assertEq(USER, funder);
    }

    function testOnlyOwnerCanWithdrawal() public funded {
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithDrawWithASingleFunder() public funded {
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 endingOwnerBlance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBlance);
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), STARTING_BALANCE);
            fundMe.fund{value: INTERNAL_AMOUNT}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 endingOwnerBlance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assert(endingFundMeBalance == 0);
        assert(startingOwnerBalance + startingFundMeBalance == endingOwnerBlance);
    }
}
