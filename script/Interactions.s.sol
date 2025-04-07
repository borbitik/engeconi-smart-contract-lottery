// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, ConstantCodes} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "@foundry-devops/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionConfig() external returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        console.log("Creating subscription on chain ID: ", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subscription ID: ", subId);
        return (subId, vrfCoordinator);
    }

    function run() external {
        this.createSubscriptionConfig();
    }
}

contract FundSubscription is Script, ConstantCodes {
    uint256 private constant LINK_AMOUNT = 3 ether;

    function fundSubscriptionConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        fundSubscription(networkConfig.subcriptionId, vrfCoordinator, networkConfig.link);
    }

    function fundSubscription(uint256 subId, address vrfCoordinator, address linkToken) public {
        console.log("Start Funding subscription: ", subId);
        
        if (block.chainid == ConstantCodes.ANVIL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, LINK_AMOUNT * 10000);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, LINK_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }

        console.log("fundSubscription done : ", subId);
    }

    function run() external {
        fundSubscriptionConfig();
    }
}

contract AddConsummer is Script {
    function addConsumerConfig(address mostRecentlyDeploy) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subId = uint256(networkConfig.subcriptionId);

        addConsumer(subId, mostRecentlyDeploy, vrfCoordinator);
    }

    function addConsumer(uint256 subId, address raffle, address vrfCoordinator) public {
        console.log("Adding consumer contract: ", raffle);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeploy = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerConfig(mostRecentlyDeploy);
    }
}
