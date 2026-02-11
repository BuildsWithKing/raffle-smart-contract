// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/Interaction.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    /// @notice MakeAddr is foundry cheatcode to create a mock address for testing purposes.
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    // ===================================== Events ==============================================
    /// @notice Emitted when a player enters the raffle
    /// @param player The address of the player that entered the raffle
    event RaffleEntered(address indexed player);

    /// @notice Emitted when a winner is picked.
    /// @param winner The address of the winner.
    event WinnerPicked(address indexed winner);

    // ===================================== Setup Function =======================================
    function setUp() public {
        // Deploy the Raffle contract using the DeployRaffle script.
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        // Fund the player's address with a starting balance for testing.
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    // ===================================== Private Helper Functions ==============================================
    function _enterRaffle_AsPlayer() private {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function _simulateUpkeepCondition() private {
        // Simulate the passage of time to trigger the upkeep condition.
        vm.warp(block.timestamp + interval + 1);
        // Simulate the passage of blocks to trigger the upkeep condition.
        vm.roll(block.number + 1);
    }

    modifier skipFork() {
        if(block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    // ===================================== Unit Tests: constructor ===============================================
    function testConstructor_InitializesRaffleCorrectly() public view {
        assertEq(raffle.getEntranceFee(), entranceFee);
        assertEq(raffle.getInterval(), interval);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
        assertEq(address(raffle.s_vrfCoordinator()), address(vrfCoordinator));
    }

    // ================================= Unit Tests: enterRaffle =================================
    function testEnterRaffle_SucceedsAndRecordsPlayers() public {
        // Call the private helper function to simulate a player entering the raffle.
        _enterRaffle_AsPlayer();

        address recordedPlayer = raffle.getPlayer(0);
        assertEq(recordedPlayer, PLAYER);
    }

    function testEnterRaffle_RevertsRaffle__SendMoreToEnterRaffle() public {
        // Expect the enterRaffle function to revert with the Raffle__SendMoreToEnterRaffle error when called with insufficient funds.
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:0}();
    }

    function testEnterRaffle_RevertsRaffle__RaffleNotOpen() public {
        // Call the private helper function to simulate a player entering the raffle.
        _enterRaffle_AsPlayer();
        _enterRaffle_AsPlayer();

        // Simulate the passage of time to trigger the upkeep condition and change the raffle state to CALCULATING.
        _simulateUpkeepCondition();
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    // =============================== Unit Tests: checkUpkeep =================================
    function testCheckUpkeep_ReturnsFalseIfItHasNoBalance() public {
        // Simulate the passage of time to trigger the upkeep condition and change the raffle state to CALCULATING.
        _simulateUpkeepCondition();
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeep_ReturnsFalseIfRaffleIsNotOpen() public {
        // Call the private helper function to simulate a player entering the raffle.
        _enterRaffle_AsPlayer();
        _enterRaffle_AsPlayer();

        // Simulate the passage of time to trigger the upkeep condition and change the raffle state to CALCULATING.
        _simulateUpkeepCondition();
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeep_ReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Call the private helper function to simulate a player entering the raffle.
        _enterRaffle_AsPlayer();
        _enterRaffle_AsPlayer();

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeep_ReturnsFalseIfPlayersAreNotMoreThanOne() public {
        // Call the private helper function to simulate a player entering the raffle.
        _enterRaffle_AsPlayer();

        // Simulate the passage of time to trigger the upkeep condition and change the raffle state to CALCULATING.
        _simulateUpkeepCondition();
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeep_ReturnsTrueIfEnoughTimeHasPassedAndHasBalanceAndIsOpen() public {
        // Call the private helper function to simulate a player entering the raffle.
        _enterRaffle_AsPlayer();
        _enterRaffle_AsPlayer();

        // Simulate the passage of time to trigger the upkeep condition and change the raffle state to CALCULATING.
        _simulateUpkeepCondition();

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    // ============================== Unit Tests: performUpkeep =================================
    function testPerformUpkeep_OnlyRunsIfCheckUpkeepIsTrue() public {
        // Call the private helper function to simulate a player entering the raffle.
        _enterRaffle_AsPlayer();
        _enterRaffle_AsPlayer();

        // Simulate the passage of time to trigger the upkeep condition and change the raffle state to CALCULATING.
        _simulateUpkeepCondition(); 

        raffle.performUpkeep("");
    }

    function testPeformUpkeep_RevertsRaffle__UpkeepNotNeeded() public {
        // Call the private helper function to simulate a player entering the raffle.
        _enterRaffle_AsPlayer();

        uint256 currentBalance = address(raffle).balance;
        uint256 numPlayers = 1;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState));
        raffle.performUpkeep("");
    }

    function testPerformUpkeep_UpdatesRaffleStateAndEmitsRequestId() public {
        _enterRaffle_AsPlayer();
        _enterRaffle_AsPlayer();
        _simulateUpkeepCondition(); 

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestedId = entries[1].topics[1];
        assert(requestedId.length > 0);

        assert(uint256(raffle.getRaffleState()) == uint256(Raffle.RaffleState.CALCULATING));
    }

    // ==================================== Unit Tests: fulfillRandomWords ========================================
    function testFulfillRandomWords_CanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public skipFork {
        _enterRaffle_AsPlayer();
        _enterRaffle_AsPlayer();
        _simulateUpkeepCondition(); 

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWords_PicksAWinnerResetsTheRaffleAndSendsMoney() public skipFork {
        _enterRaffle_AsPlayer();

        uint256 additionalEntrants = 3; // 4 total entrants including the initial player.
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        _simulateUpkeepCondition();

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
        uint256 prize = entranceFee *(additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimestamp > startingTimestamp);
    }
}