// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script,console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscription is Script {
    function createSubscriptionConfig() external returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) { 
        console.log("Creating subscription on chain ID: ",block.chainid);  
        vm.startBroadcast();       
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subscription ID: ",subId);
        return (subId, vrfCoordinator);
    }

    function run() external {
        this.createSubscriptionConfig();
    }
}

contract FundSubscription is Script {

    uint256 private constant LINK_AMOUNT = 3 ether;

    function fundSubscriptionConfig() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        
      
     
       
    }

    function fundSubscription(uint256 subId, address vrfCoordinator) public {
         vm.startBroadcast();

       
    }

    function run() external {
    
    }
}