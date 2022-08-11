// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

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

    // moving all configs under a 256 bit space to save cost
    struct Config {
        uint64 allowlistPrice;
        uint64 publicPrice;
        uint16 maxSupply;
        uint16 maxQuantityPerAllowlist; // max quantity per allowlist address
        uint16 maxQuantityPerPublic; // max quantity per public mint address
        uint80 misc; // available padding bits,
    }
    Config public config;
    bytes32 public merkleRoot;

    // EVENTS
    event Minted(address minter, uint256 amount);
    event BaseURIChanged(string newBaseURI);
    event StatusChanged(Status status);
    event MerkleRootChanged(bytes32 merkleRoot);

    // CONSTRUCTOR
    constructor(string memory initBaseURI) ERC721A("GuoChanLiangXin", "GCLX") {
        baseURI = initBaseURI;
        config.allowlistPrice = 0.005 ether;
        config.publicPrice = 0.01 ether;
        config.maxSupply = 1000;
        config.maxQuantityPerAllowlist = 2;
        config.maxQuantityPerPublic = 2;
    }

    // MODIFIERS
    function mintComplianceBase(uint256 _qunatity) public view {
        require(
            totalSupply() + _qunatity <= config.maxSupply,
            "GCLX: Mei zhe me duo le."
        );
    }

    modifier mintComplianceForPublic(uint256 _qunatity) {
        mintComplianceBase(_qunatity);
        require(status == Status.Started, "GCLX: Hai mei kai shi");
        require(
            numberMintedForPublic(msg.sender) + _qunatity <=
                config.maxQuantityPerPublic,
            "GCLX: Zui duo lia"
        );
        _;
    }

    modifier mintComplianceForAllowList(uint256 _qunatity) {
        mintComplianceBase(_qunatity);
        require(
            status == Status.AllowListOnly || status == Status.Started,
            "GCLX: Hai mei kai shi."
        );
        require(
            numberMintedForAllowList(msg.sender) + _qunatity <=
                config.maxQuantityPerAllowlist,
            "GCLX: Zui duo lia(bai ming dan)"
        );
        _;
    }

    modifier OnlyInAllowList(address owner, bytes32[] calldata _merkleProof) {
        bytes32 leaf = keccak256(abi.encodePacked(owner));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "GCLX: Ni bu zai bai ming dan li."
        );
        _;
    }

    modifier OnlyUser() {
        require(tx.origin == msg.sender, "GCLX: Bu yun xu he yue diao yong.");
        _;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // MINTING LOGICS
    function mint(uint256 quantity)
        external
        payable
        OnlyUser
        mintComplianceForPublic(quantity)
    {
        _safeMint(msg.sender, quantity);
        refundIfOver(config.publicPrice * quantity);
        emit Minted(msg.sender, quantity);
    }

    function allowlistMint(uint256 quantity, bytes32[] calldata _merkleProof)
        external
        payable
        OnlyUser
        OnlyInAllowList(_msgSender(), _merkleProof)
        mintComplianceForAllowList(quantity)
    {
        // Use Aux to store # of minted for allow list
        _setAux(_msgSender(), _getAux(_msgSender()) + uint64(quantity));
        _safeMint(_msgSender(), quantity);
        refundIfOver(config.allowlistPrice * quantity);
        emit Minted(msg.sender, quantity);
    }

    function numberMintedForPublic(address owner)
        public
        view
        returns (uint256)
    {
        return _numberMinted(owner) - uint256(_getAux(owner));
    }

    function numberMintedForAllowList(address owner)
        public
        view
        returns (uint256)
    {
        return uint256(_getAux(owner));
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "GCLX: Mei duo gei ETH.");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    // SETTERS
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

    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        require(
            _maxSupply < config.maxSupply,
            "LED: Cannot increase the supply"
        );
        config.maxSupply = uint16(_maxSupply);
    }

    function setMaxQuantiyPerAddress(
        uint256 _maxQuantityPerAllowlist,
        uint256 _maxQuantityPerPublic
    ) public onlyOwner {
        config.maxQuantityPerAllowlist = uint16(_maxQuantityPerAllowlist);
        config.maxQuantityPerPublic = uint16(_maxQuantityPerPublic);
    }

    function setPrice(uint256 _allowlistPrice, uint256 _publicPrice)
        public
        onlyOwner
    {
        config.allowlistPrice = uint64(_allowlistPrice);
        config.publicPrice = uint64(_publicPrice);
    }

    // WITHDRAW
    function withdraw(address payable recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = recipient.call{value: balance}("");
        require(success, "GCLX: Wan le, quan wan le.");
    }
}
