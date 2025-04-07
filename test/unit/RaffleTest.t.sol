// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

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
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();
        entranceFee = networkConfig.entranceFee;
        keyHash = networkConfig.keyHash;
        subcriptionId = networkConfig.subcriptionId;
        intervalTime = networkConfig.intervalTime;
        callbackGasLimit = networkConfig.callbackGasLimit;
        vrfCoordinator = networkConfig.vrfCoordinator;
        vm.deal(PLAYER, STARTING_PLAYERS_BALANCE);
    }

    function testRaffleInitializeInOpenState() public {
        assertTrue(
            raffle.getRaffleState() == Raffle.RaffleState.OPEN,
            "Raffle should be in open state"
        );
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
    /*
        TESTS CHEKUPKEEP
    */

    function testCheckUpKeepRetunsFalsesIfBlocckTimeNotPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervalTime - 1);
        //Act
        (bool upkeepNeed, ) = raffle.checkUpkeep("");

        //Assert
        assertFalse(upkeepNeed, "Upkeep should not be needed");
    }

    function testRaffleShouldBeOpen() public raffleEntered {
        raffle.enterRaffle{value: entranceFee}();

        //Act/assert
        raffle.performUpkeep("");
        (bool upkeepNeed, ) = raffle.checkUpkeep("");
        assertFalse(upkeepNeed, "Upkeep should not be needed");
    }

    /*
    PERFORM UPKEEP TESTS
    */

    function testCannotPerformUpkeepIfCheckUpKeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 playerCount = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        playerCount = playerCount + 1;

        //Act/Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                playerCount,
                uint256(raffleState),
                raffle.getLastTimeStamp()
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeep() public raffleEntered {
        //Arrange
        raffle.enterRaffle{value: entranceFee}();
        vm.recordLogs();
        //Act
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        //assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assertTrue(
            raffleState == Raffle.RaffleState.CALCULATING,
            "Raffle should be in calculating state"
        );
        assertTrue(uint256(requestId) > 0, "RequestId should not be zero");
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.number + 1);
        _;
    }

    /*
        TESTS FULFILL RANDOM WORDS
    */

    function testFullfilRandomCanBeCallOnlyAfterPerformUpKeep(
        uint256 requestId
    ) public raffleEntered {
        //Arrange/Act/Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        
        // Fund and enter additional players
        for (uint256 i = startingIndex; i <= additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_PLAYERS_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 afterRaffleEntranceBalance = STARTING_PLAYERS_BALANCE - entranceFee;
        
        uint256 totalPrize = entranceFee * (additionalEntrants + 1); // +1 for initial player
        uint256 startingTimestamp = raffle.getLastTimeStamp();

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 endingTimestamp = raffle.getLastTimeStamp();

        assert(recentWinner != address(0));
        assert(raffle.getPlayerCount() == 0);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(endingTimestamp > startingTimestamp);
        assertEq(recentWinner.balance, totalPrize + afterRaffleEntranceBalance);
    }
}
