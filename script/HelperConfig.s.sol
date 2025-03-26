//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract ConstantCodes {
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant ANVIL_CHAIN_ID = 31337;
    uint256 internal constant MAINNET_CHAIN_ID = 1;

    uint96 internal constant BASE_FEE = 0.25 ether;
    uint96 internal constant GAS_PRICE_LINK = 1e9;
    int256 internal constant WEI_PER_UNIT_LINK = 4e15;
}

contract HelperConfig is ConstantCodes, Script {
    /**
     * errors
     */
    error HelperConfig__ChainIdNotSupported(uint256 chainId);

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public NetworkConfigs;

    struct NetworkConfig {
        uint256 entranceFee;
        bytes32 keyHash;
        uint256 subcriptionId;
        uint256 intervalTime;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        address link;
    }

    constructor() {
        NetworkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getSepoliaEthConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.1 ether,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subcriptionId: 0,
            intervalTime: 30, //seconds
            callbackGasLimit: 500000,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link:0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvil() private returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK);

        vm.stopBroadcast();
        localNetworkConfig = NetworkConfig({
            entranceFee: 0.1 ether,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subcriptionId: 0,
            intervalTime: 30, //seconds
            callbackGasLimit: 500000,
            vrfCoordinator: address(vrfCoordinator)
        });
        return localNetworkConfig;
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getNetworkConfig(block.chainid);
    }

    function getNetworkConfig(uint256 chainId) private returns (NetworkConfig memory) {
        if (NetworkConfigs[chainId].vrfCoordinator != address(0)) {
            return NetworkConfigs[chainId];
        } else if (chainId == ANVIL_CHAIN_ID) {
            return getOrCreateAnvil();
        } else {
            revert HelperConfig__ChainIdNotSupported(chainId);
        }
    }
}
