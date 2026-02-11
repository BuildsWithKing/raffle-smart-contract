// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Imports the Script contract from the forge-std library, and the Raffle contract.
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    // ============================= VRF MOCK VALUES ==========================
    uint96 public constant MOCK_BASE_FEE = 0.0001 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    uint256 public constant MINIMUM_ENTRANCE_FEE = 0.01 ether;
    uint256 public constant INTERVAL = 30; // 30 seconds
    address public s_vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 public constant GAS_LANE = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 public constant CALLBACK_GAS_LIMIT = 500000; // 500,000 gas

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getConfig() public returns(NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaEthConfig = NetworkConfig({
            entranceFee: MINIMUM_ENTRANCE_FEE, // 10000000000000000
            interval: INTERVAL, 
            vrfCoordinator: s_vrfCoordinator,
            gasLane: GAS_LANE,
            subscriptionId: 80347149478299967095994222948394726518165611613272991428049457674216569840309,
            callbackGasLimit: CALLBACK_GAS_LIMIT, // 500,000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x63c013128BF5C7628Fc8B87b68Aa90442AF312aa
        });

        return sepoliaEthConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if(localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks and such
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: MINIMUM_ENTRANCE_FEE, // 10000000000000000
            interval: INTERVAL, 
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: GAS_LANE,
            subscriptionId: 0,
            callbackGasLimit: CALLBACK_GAS_LIMIT, // 500,000 gas  
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}