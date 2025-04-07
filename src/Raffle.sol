//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/Script.sol";

/**
 * @title a simple raffle contract
 * @author Borbitik
 * @notice
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* errors */
    error Raffle__NotEnoughEtherSent();
    error Raffle__TransactionFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance, uint256 playersLength, uint256 raffleState, uint256 lastTimeOpenRaffle
    );

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subcriptionId;
    uint256 private immutable i_intervalTime;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_recentWinner;
    uint256 private constant SUSCRIPTION_ID =
        66309290523100166155524790583768970285470496330233240053463583814363598219221;
    RaffleState private s_raffleState;

    /* events */
    event RaffleEntered(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestCreated(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        bytes32 keykash,
        uint256 subcriptionId,
        uint256 intervalTime,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_keyHash = keykash;
        i_subcriptionId = subcriptionId;
        i_intervalTime = intervalTime;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        // ckecks
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEtherSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        //Effects
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(bytes calldata /* checkData */ )
        external
        view
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        bool timeHasPassed = block.timestamp >= s_lastTimeStamp + i_intervalTime;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        //checks
        //check to see if enough time has passed
        (bool upkeepNeeded,) = this.checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance, s_players.length, uint256(s_raffleState), s_lastTimeStamp
            );
        }
        //Effects
        s_raffleState = RaffleState.CALCULATING;

        //Interactions
        /* pick a random winner */
       uint256 requestId =  s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subcriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1(false))
            })
        );
        emit RequestCreated(requestId);
    }

    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal virtual override {
        //checks

        //effect (internal Contract state)
        console.log("Random number: %s", randomWords[0]);
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        s_recentWinner = s_players[indexOfWinner];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(s_recentWinner);

        //Interactions (External Contract interactions)
        (bool sucess,) = s_recentWinner.call{value: address(this).balance}("");
        if (!sucess) {
            revert Raffle__TransactionFailed();
        }
    }

    /**
     * Get entranceFee
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayerCount() external view returns (uint256) {
        return s_players.length;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
