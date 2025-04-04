//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsummer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }

    function deployRaffle() private returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;

        if (networkConfig.subcriptionId == 0) {
            //create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (uint256 subId,) = createSubscription.createSubscription(vrfCoordinator);
            networkConfig.subcriptionId = subId;
            networkConfig.vrfCoordinator = vrfCoordinator;
            //fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(subId, vrfCoordinator, networkConfig.link);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.keyHash,
            networkConfig.subcriptionId,
            networkConfig.intervalTime,
            networkConfig.callbackGasLimit,
            networkConfig.vrfCoordinator
        );

        vm.stopBroadcast();

        // after all add consumer
        AddConsummer addConsummer = new AddConsummer();
        addConsummer.addConsumer(networkConfig.subcriptionId,address(raffle),networkConfig.vrfCoordinator);
        return (raffle, helperConfig);
    }
}
