//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./askmi-functions.sol";

// @title A question-and-answer smart contract
// @author Diego Ramos
// @notice This contract is unadited
// @dev Any mention of ERC20 tokens implies that the zero address (0x0) is used to represent ether (ETH), as if ether was an ERC20 token with address 0x0.
// @custom:roles responder: Owner of an askmi instance and the only person allowed to answer questions and change the contracts' settings. questioner: Anyone with an EOA who decides to ask a question. exchange: The exchange between the questioner asking as question and the responder answering it
contract AskMi {
    /* ---------- VARIABLES ---------- */
    // @notice The owner of this smart contract (askmi instance)
    address public _owner;

    // @dev Variable used to prevent re-entrancy
    bool private _locked;

    // @notice Prevents the ask() function from being called
    bool public _disabled;

    // @notice The tip cost and token address for all exchanges
    Tip private _tip;

    // @dev Address designated to receive all dev fees
    address private _developer;

    // @notice The dev fee percentage (balance/200 = 0.5%)
    uint256 public _fee = 200;

    // @notice An array of all unique addresses which have asked a question
    address[] private _questioners;

    // @notice Mapping pointing to the possition of a questioner in the questioners array
    mapping(address => uint256) private _questionersIndex;

    // @notice The list of questions from a questioner
    mapping(address => Exchange[]) private _exchanges;

    // @notice List of token addresses accepted as payment by the responder
    address[] private _supportedTokens;

    // @dev Mapping pointing to the possition of supported tokens in the supportedTokens array
    mapping(address => uint256) private _supportedTokensIndex;

    // @dev The tiers for each supported token
    mapping(address => uint256[]) private _tiers;

    /* ---------- STRUCTS ---------- */

    // The multihash representation of an IPFS' CID
    struct Cid {
        string digest;
        uint256 hashFunction;
        uint256 size;
    }

    struct Tip {
        address token;
        uint256 tip;
    }

    struct Exchange {
        Cid question;
        Cid answer;
        address token;
        uint256 exchangeIndex;
        // The balance in wei paid to the owner for a response
        // This will vary depending on the price tiers
        uint256 balance;
        uint256 tips;
    }

    /* ---------- CONSTRUCTOR ---------- */

    // @param developer The developer's address
    // @param owner This contract's owner
    constructor(address developer, address owner) {
        _developer = developer;
        _owner = owner;

        // Occupy the first index of the questioners
        // array to allow for array lookups
        _questioners.push(address(0));
    }

    /* ---------- EVENTS ---------- */

    event QuestionAnswered(address questioner, uint256 exchangeIndex);

    /* ---------- GETTER FUNCTIONS ---------- */

    // @return The complete array of supported tokens
    function supportedTokens() external view returns (address[] memory) {
        return _supportedTokens;
    }

    // @return The tip cost and the token address
    function tipAndToken() external view returns (uint256, address) {
        return (_tip.tip, _tip.token);
    }

    // @param token Any ERC20 token address
    // @return The tiers corresponding to the input address
    function getTiers(address token) external view returns (uint256[] memory) {
        return _tiers[token];
    }

    // @return The complete set of questioners as an array
    function questioners() external view returns (address[] memory) {
        return _questioners;
    }

    // @param questioner Address of one questioner from the questioners set
    // @return The complete array of exchanges started by a questioner
    function questions(address questioner)
        external
        view
        returns (Exchange[] memory)
    {
        return _exchanges[questioner];
    }

    /* ---------- UPDATE FUNCTIONS ---------- */

    // @notice Disable or enable the ask() function
    function toggleDisabled(address functionsContract) external {
        (bool success, ) = functionsContract.delegatecall(
            abi.encodeWithSignature("toggleDisabled()")
        );
        require(success, "toggleDisabled() failed");
    }

    // @notice Update the tiers for any token. If the new tiers array is empty, support for the selected token will be dropped. If the token was no supported and new tiers are added, support for the token will be enabled
    // @param functionsContract Contract with functions to modify state in this contract
    // @param token Any ERC20 token
    // @param tiers The tiers for the selected token
    function updateTiers(
        address functionsContract,
        address token,
        uint256[] memory tiers
    ) external {
        (bool success, ) = functionsContract.delegatecall(
            abi.encodeWithSignature(
                "updateTiers(address,uint256[])",
                token,
                tiers
            )
        );
        require(success, "updateTiers() failed");
    }

    // @notice Update the tip amount and the supported token for tipping
    // @param tip The cost for people to tip
    // @param token Any ERC20 token
    function updateTip(
        address functionsContract,
        uint256 tip,
        address token
    ) external {
        (bool success, ) = functionsContract.delegatecall(
            abi.encodeWithSignature("updateTip(uint256,address)", tip, token)
        );
        require(success, "updateTip() failed");
    }

    /* ---------- PRIMARY FUNCTIONS ---------- */

    // @notice Ask a question to the owner
    // @param functionsContract Contract with functions to modify state in this contract
    // @param token Address of a supported token
    // @param digest The digest output of hash function in hex with prepended '0x'
    // @param hashFunction The hash function code for the function used
    // @param size The length of digest
    // @param tierIndex The index of the selected tier in the _tiers array
    function ask(
        address functionsContract,
        address token,
        string memory digest,
        uint256 hashFunction,
        uint256 size,
        uint256 tierIndex
    ) external payable {
        (bool success, ) = functionsContract.delegatecall(
            abi.encodeWithSignature(
                "ask(address,string,uint256,uint256,uint256)",
                token,
                digest,
                hashFunction,
                size,
                tierIndex
            )
        );
        require(success, "ask() failed");
    }

    // @notice The questioner or the responder can remove a question and a refund is issued
    // @param functionsContract Contract with functions to modify state in this contract
    // @param questioner The questioner's address
    // @param exchangeIndex Index of the selected exchange in the questioners' exchanges array
    function remove(
        address functionsContract,
        address questioner,
        uint256 exchangeIndex
    ) external {
        (bool success, ) = functionsContract.delegatecall(
            abi.encodeWithSignature(
                "remove(address,uint256)",
                questioner,
                exchangeIndex
            )
        );
        require(success, "remove() failed");
    }

    // @notice The owner answers a question
    // @param functionsContract Contract with functions to modify state in this contract
    // @param questioner The questioner's address
    // @param digest The digest output of hash function in hex with prepended '0x'
    // @param hashFunction The hash function code for the function used
    // @param size The length of digest
    // @param exchangeIndex Index of the selected exchange in the questioners' exchanges array
    function respond(
        address functionsContract,
        address questioner,
        string memory digest,
        uint256 hashFunction,
        uint256 size,
        uint256 exchangeIndex
    ) external {
        (bool success, ) = functionsContract.delegatecall(
            abi.encodeWithSignature(
                "respond(address,string,uint256,uint256,uint256)",
                questioner,
                digest,
                hashFunction,
                size,
                exchangeIndex
            )
        );
        require(success, "respond() failed");

        emit QuestionAnswered(questioner, exchangeIndex);
    }

    // @notice Tip an exchange to highlight helpful content
    // @param functionsContract Contract with functions to modify state in this contract
    // @param questioner The questioner's address
    // @param exchangeIndex Index of the selected exchange in the questioners' exchanges array
    function issueTip(
        address functionsContract,
        address questioner,
        uint256 exchangeIndex
    ) external payable {
        (bool success, ) = functionsContract.delegatecall(
            abi.encodeWithSignature(
                "issueTip(address,uint256)",
                questioner,
                exchangeIndex
            )
        );
        require(success, "issueTip() failed");
    }
}
