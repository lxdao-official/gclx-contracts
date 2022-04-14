// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "erc721a/contracts/ERC721A.sol";

contract GCLX is ERC721A, Ownable {
    enum Status {
        Waiting,
        Started,
        Finished,
        AllowListOnly
    }

    Status public status;
    string public baseURI;
    bytes32 public merkleRoot;
    uint256 public constant MAX_MINT_PER_ADDR = 2;
    uint256 public constant MAX_MINT_ALLOWLIST = 2;
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant PRICE = 0.01 * 10**18; // 0.01 ETH

    mapping(address => uint256) public allowlist;
    mapping(address => uint256) public allowlistClaimed;

    event Minted(address minter, uint256 amount);
    event StatusChanged(Status status);
    event BaseURIChanged(string newBaseURI);
    event MerkleRootChanged(bytes32 merkleRoot);

    constructor(string memory initBaseURI) ERC721A("GuoChanLiangXin", "GCLX") {
        baseURI = initBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function mint(uint256 quantity) external payable {
        require(status == Status.Started, "GCLX: Hai mei kai shi.");
        require(tx.origin == msg.sender, "GCLX: Bu yun xu he yue diao yong.");
        require(
            numberMinted(msg.sender) + quantity <= MAX_MINT_PER_ADDR,
            "GCLX: Zui duo lia."
        );
        require(
            totalSupply() + quantity <= MAX_SUPPLY,
            "GCLX: Mei zhe me duo le."
        );

        _safeMint(msg.sender, quantity);
        refundIfOver(PRICE * quantity);

        emit Minted(msg.sender, quantity);
    }

    function allowlistMint(uint256 quantity) external payable {
        require(allowlist[msg.sender] > 0, "GCLX: Ni bu zai bai ming dan li.");
        require(
            status == Status.Started || status == Status.AllowListOnly,
            "GCLX: Hai mei kai shi."
        );
        require(tx.origin == msg.sender, "GCLX: Bu yun xu he yue diao yong.");
        require(quantity <= allowlist[msg.sender], "GCLX: Nin tai tan xin le.");
        require(
            totalSupply() + quantity <= MAX_SUPPLY,
            "GCLX: Mei zhe me duo le."
        );
        allowlist[msg.sender] = allowlist[msg.sender] - quantity;
        _safeMint(msg.sender, quantity);
        refundIfOver(PRICE * quantity);

        emit Minted(msg.sender, quantity);
    }

    function seedAllowlist(
        address[] memory addresses,
        uint256[] memory numSlots
    ) external onlyOwner {
        require(addresses.length == numSlots.length, "GCLX: di zhi bu dui.");
        for (uint256 i = 0; i < addresses.length; i++) {
            allowlist[addresses[i]] = numSlots[i];
        }
    }

    function allowlistMintMerkleProof(
        uint256 quantity,
        bytes32[] calldata _merkleProof
    ) external payable {
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        require(
            status == Status.Started || status == Status.AllowListOnly,
            "GCLX: Hai mei kai shi."
        );
        require(tx.origin == msg.sender, "GCLX: Bu yun xu he yue diao yong.");
        require(
            totalSupply() + quantity <= MAX_SUPPLY,
            "GCLX: Mei zhe me duo le."
        );
        require(
            (allowlistClaimed[_msgSender()] < MAX_MINT_ALLOWLIST),
            "GCLX: Ling guo le."
        );
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "GCLX: Ni bu zai bai ming dan li."
        );
        require(
            quantity <= MAX_MINT_ALLOWLIST - allowlistClaimed[_msgSender()],
            "GCLX: Nin tai tan xin le."
        );

        allowlistClaimed[_msgSender()] += quantity;
        _safeMint(_msgSender(), quantity);
        refundIfOver(PRICE * quantity);
        emit Minted(msg.sender, quantity);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "GCLX: Mei duo gei ETH.");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function setStatus(Status _status) external onlyOwner {
        status = _status;
        emit StatusChanged(status);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootChanged(merkleRoot);
    }

    function withdraw(address payable recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = recipient.call{value: balance}("");
        require(success, "GCLX: Wan le, quan wan le.");
    }
}
