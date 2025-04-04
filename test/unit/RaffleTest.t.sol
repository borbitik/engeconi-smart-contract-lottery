// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    uint256 entranceFee;
    bytes32 keyHash;
    uint256 subcriptionId;
    uint256 intervalTime;
    uint32 callbackGasLimit;
    address vrfCoordinator;

    Raffle private raffle;
    HelperConfig private helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYERS_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event PickedWinner(address indexed winner);

    function setUp() public {
        (raffle, helperConfig) = new DeployRaffle().run();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        entranceFee = networkConfig.entranceFee;
        keyHash = networkConfig.keyHash;
        subcriptionId = networkConfig.subcriptionId;
        intervalTime = networkConfig.intervalTime;
        callbackGasLimit = networkConfig.callbackGasLimit;
        vrfCoordinator = networkConfig.vrfCoordinator;
        vm.deal(PLAYER, STARTING_PLAYERS_BALANCE);
    }

    function testRaffleInitializeInOpenState() public {
        assertTrue(raffle.getRaffleState() == Raffle.RaffleState.OPEN, "Raffle should be in open state");
    }

    function testRaffleDeployMent() public view {
        assertTrue(address(raffle) != address(0), "Raffle should be deployed");
    }

    function testNotEnoughEtherSent() public {
        //Arrange
        vm.prank(PLAYER);

        //Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEtherSent.selector);

        //Act
        raffle.enterRaffle();
    }

    function testRaffleEnter() public {
        //Arrange
        vm.prank(PLAYER);

        //Act
        raffle.enterRaffle{value: entranceFee}();
        address recordedPlayer = raffle.getPlayers(0);

        //Assert
        assertTrue(recordedPlayer == PLAYER, "Player should be recorded");
    }

    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);

        //Act/Assert

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCannotEnterRaffleWhenSelectedWinner() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.number + 1);

        //ACT/assert
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepRetunsFalsesIfBlocckTimeNotPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        //Act
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector,address(raffle).balance, 1, 0, 1));
         raffle.performUpkeep("");

    
    }
}
