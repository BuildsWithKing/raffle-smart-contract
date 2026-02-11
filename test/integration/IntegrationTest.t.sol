// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interaction.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/Interaction.s.sol";

contract IntegrationTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;
    CreateSubscription public createSubscription;
    FundSubscription public fundSubscription;
    AddConsumer public addConsumer;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    /// @notice MakeAddr is foundry cheatcode to create a mock address for testing purposes.
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    // ===================================== Setup Function ==================================
    function setUp() public {
        createSubscription = new CreateSubscription();
        createSubscription.run();
        (subscriptionId, vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();

        fundSubscription = new FundSubscription();

        addConsumer = new AddConsumer();

        DeployRaffle deployer = new DeployRaffle();
        deployer.run();
        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRafflePicksAWinnerResetsAndPaysWinner_Succeeds() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        uint256 additionalEntrants = 3; // 4 total entrants including the initial player.
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        uint256 startingTimestamp = raffle.getLastTimestamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestedId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestedId), address(raffle));

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimestamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimestamp > startingTimestamp);
    }

    // ======================================== Unit Test: HelperConfig ====================================
    function testGetConfigByChainId_Returns() public {
        HelperConfig.NetworkConfig memory sepoliaConfig = helperConfig.getConfigByChainId(SEPOLIA_CHAIN_ID);

        assert(sepoliaConfig.entranceFee == entranceFee);
        assert(sepoliaConfig.interval == interval);

        HelperConfig.NetworkConfig memory localConfig = helperConfig.getConfigByChainId(LOCAL_CHAIN_ID);

        assert(localConfig.entranceFee == entranceFee);
        assert(localConfig.interval == interval);
    }

    function testFuzzGetConfigByChainId_RevertsHelperConfig__InvalidChainId(uint256 id) public {
        vm.expectRevert(abi.encodeWithSelector(HelperConfig.HelperConfig__InvalidChainId.selector, id));
        helperConfig.getConfigByChainId(id);
    }

    function testGetOrCreateAnvilEthConfig_Returns() public {
        HelperConfig.NetworkConfig memory localConfig = helperConfig.getOrCreateAnvilEthConfig();

        assert(localConfig.entranceFee == entranceFee);
        assert(localConfig.interval == interval);
    }
}
