//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }

    function deployRaffle() private returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;

        if (networkConfig.subcriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (uint256 subId,) = createSubscription.createSubscription(vrfCoordinator);
            networkConfig.subcriptionId = subId;
            networkConfig.vrfCoordinator = vrfCoordinator;
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
        return (raffle, helperConfig);
    }
}
