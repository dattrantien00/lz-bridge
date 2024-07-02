// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TrustKeysPetDrop is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public addressMarketplace;
    address public addressAuction;

    uint64 public startTime;
    uint64 public endTime;

    uint256 public totalLimit;

    address public addressCurrency;
    uint256 public feeMint;
    bool public everyoneCanMint;

    struct MintInfo {
        address receiver;
        string uri;
    }
    event MintAndApproveMarket(uint256 tokenId, address to, string uri);
    event Burn(uint256 tokenId);
    event MintBatch(MintInfo[] batch);

    constructor(
        string memory _name,
        string memory _symbol,
        address _addressMarketplace,
        address _addressAuction,
        uint64 _startTime,
        uint64 _endTime,
        uint256 _totalLimit,
        address _addressCurrency,
        uint256 _feeMint,
        bool _everyoneCanMint
    ) ERC721(_name, _symbol) {
        addressMarketplace = _addressMarketplace;
        addressAuction = _addressAuction;
        startTime = _startTime;
        endTime = _endTime;
        totalLimit = _totalLimit;
        addressCurrency = _addressCurrency;
        feeMint = _feeMint;
        everyoneCanMint = _everyoneCanMint;
    }

    function claim(address receiver, string memory uri) public payable {
        if (msg.sender != owner()) {
            require(block.timestamp > startTime, "not started yet");
            require(block.timestamp < endTime, "finished");
        }

        if (!everyoneCanMint) {
            require(msg.sender == owner(), "Only owner can mint");
        }
        if (totalLimit != 0) {
            require(_tokenIds.current() < totalLimit, "limited");
        }

        if (feeMint != 0 && msg.sender != owner()) {
            if (
                address(addressCurrency) ==
                0x0000000000000000000000000000000000000000
            ) {
                (bool sent, ) = owner().call{value: feeMint}("");
                require(sent, "Failed to send BNB to owner");
            } else {
                IERC20(addressCurrency).transferFrom(
                    msg.sender,
                    owner(),
                    feeMint
                );
            }
        }

        _tokenIds.increment();

        uint256 newId = _tokenIds.current();
        _mint(receiver, newId, uri);
        _approveMarket(msg.sender);

        emit MintAndApproveMarket(newId, receiver, uri);
    }

    function mintBatch(MintInfo[] calldata batch) public onlyOwner {
        for (uint256 i = 0; i < batch.length; i++) {
            _tokenIds.increment();
            uint256 newId = _tokenIds.current();
            _mint(batch[i].receiver, newId, batch[i].uri);
            _approveMarket(msg.sender);
            emit MintAndApproveMarket(newId, batch[i].receiver, batch[i].uri);
        }
        // emit MintBatch(batch);
    }

    function _mint(address to, uint256 newId, string memory uri) internal {
        _safeMint(to, newId);
        _setTokenURI(newId, uri);
    }

    function _approveMarket(address to) internal {
        _setApprovalForAll(to, addressMarketplace, true);
        _setApprovalForAll(to, addressAuction, true);
    }

    function burn(uint256 _tokenId) public {
        require(
            msg.sender == owner() || msg.sender == ownerOf(_tokenId),
            "not permision"
        );
        _burn(_tokenId);

        emit Burn(_tokenId);
    }

    function getCreatorByTokenId(
        uint256 tokenId
    ) public view returns (address) {
        return owner();
    }

    function setTrustKeysMarketplace(
        address _addressMarketplace
    ) public onlyOwner {
        addressMarketplace = _addressMarketplace;
    }

    function setTrustKeysAuction(address _addressAuction) public onlyOwner {
        addressAuction = _addressAuction;
    }

    function setFeeMint(
        address _addressCurrency,
        uint256 _feeMint
    ) public onlyOwner {
        addressCurrency = _addressCurrency;
        feeMint = _feeMint;
    }

    function setTime(uint64 _startTime, uint64 _endTime) public onlyOwner {
        startTime = _startTime;
        endTime = _endTime;
    }

    function setTotalLimit(uint256 _totalLimit) public onlyOwner {
        totalLimit = _totalLimit;
    }

    function getNextTokenIdsId() public view returns (uint256) {
       return  _tokenIds.current()+1;
    }
}
