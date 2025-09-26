// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.26;

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
}

contract ERC721 is IERC721 {
    string public name;
    string public symbol;

    mapping(uint256 => address) private _tokenOwner;
    mapping(address => uint256) private _ownedTokensCount;
    mapping(uint256 => address) private _tokenApprovals;

    address public owner;

    // Simple incrementing counter for issuing new token IDs
    uint256 private _tokenIdCounter = 0;

    modifier onlyOwner() {
        require(msg.sender == owner, "ERC721: caller is not the owner");
        _;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for zero address");
        return _ownedTokensCount[owner];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address tokenOwner = _tokenOwner[tokenId];
        require(tokenOwner != address(0), "ERC721: owner query for nonexistent token");
        return tokenOwner;
    }

    function _approve(address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function approve(address to, uint256 tokenId) public override {
        address tokenOwner = ownerOf(tokenId);
        require(msg.sender == tokenOwner, "ERC721: approval to non-owner");
        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_tokenOwner[tokenId] != address(0), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(from != address(0), "ERC721: transfer from zero address");
        require(to != address(0), "ERC721: transfer to zero address");
        
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == from, "ERC721: transfer of token that is not own");
        require(msg.sender == from || getApproved(tokenId) == msg.sender, "ERC721: caller is not owner nor approved");

        // Clear previous approved addresses
        _approve(address(0), tokenId);

        _ownedTokensCount[from] -= 1;
        _ownedTokensCount[to] += 1;
        _tokenOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function mint(address to) public onlyOwner {
        require(to != address(0), "ERC721: mint to zero address");

        uint256 newTokenId = _tokenIdCounter;
        _tokenIdCounter += 1;

        _tokenOwner[newTokenId] = to;
        _ownedTokensCount[to] += 1;

        emit Transfer(address(0), to, newTokenId);
    }
}
