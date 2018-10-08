pragma solidity ^0.4.21;
import "openzeppelin-zos/contracts/token/ERC721/MintableERC721Token.sol";
import "openzeppelin-zos/contracts/lifecycle/Pausable.sol";

/**
 * @title CBBC (Crypto Baseball Cards)
 */
contract Cbbc is MintableERC721Token, Pausable {

  /// @dev Emit this event whenever we mint a new 5 pack of cards (see mintFivePack below)
  event FivePackMinted(uint16 _editionId, address indexed _owner);
  /// @dev Emit this event whenever we mint a new card (see _mintCard below)
  event CardMinted(string _playerBbrefId, uint16 _editionId, uint256 _cardId, address indexed _owner);

  /// @dev The struct representing the Crypto Baseball card.
  struct Card {
    // The timestamp at which this card was minted.
    uint64 mintTime;

    // The BBREF ID of the player represented by the card
    string playerBbrefId;

    // The CBBC Edition ID that the card belongs to
    uint16 editionId;

    // Cards for a given player and edition have a series number, which gets
    // incremented in sequence. If we mint 100 cards of a given player in an edition,
    // the 21st one to be minted has serialNumber = 21 of 100.
    uint16 seriesNumber;
  }

  /*** STORAGE ***/

  /// @dev All the cards that have been minted, indexed by cardId.
  Card[] public cards;

  /// @dev Keeps track of how many cards we have minted for a given player and edition
  mapping (string => mapping (uint16 => uint16)) internal mintedCountForPlayerBbrefIdAndEditionId;

  // @dev The API Base URI
  string constant API_BASE_URI = "http//www.crypto-baseball-cards.com/cards/";

  /// @dev We initialize with the standard params and add a base API URL.
  /// @param _sender is the Contract owner.
  /// @param _name is the CBBC ERC721 token name.
  /// @param _symbol is the CBBC ERC721 token symbol.
  /// @return The 10 new card IDs.
  function initialize(address _sender, string _name, string _symbol) isInitializer("Cbbc", "0.1.0")  public {
    Ownable.initialize(_sender);
    ERC721Token.initialize(_name, _symbol);
  }

  /// @dev Allows the contract owner to mint a pack of 5 cards.
  /// @param _playerBbrefId1 through _playerBbrefId5 are the player BBREF IDs for the 5 new cards.
  /// @param _editionId is the CBBC edition ID for the 5 new cards.
  /// @param _owner is the pack's owner.
  /// @return The 5 new card IDs.
  function mintFivePack(
    string _playerBbrefId1,
    string _playerBbrefId2,
    string _playerBbrefId3,
    string _playerBbrefId4,
    string _playerBbrefId5,
    uint16 _editionId,
    address _owner
  )
  external onlyOwner
  returns (uint256[5])
  {
    uint256[5] memory cardIds;
    emit FivePackMinted(_editionId, _owner);
    cardIds[0] = _mintCard(_playerBbrefId1, _editionId, _owner);
    cardIds[1] = _mintCard(_playerBbrefId2, _editionId, _owner);
    cardIds[2] = _mintCard(_playerBbrefId3, _editionId, _owner);
    cardIds[3] = _mintCard(_playerBbrefId4, _editionId, _owner);
    cardIds[4] = _mintCard(_playerBbrefId5, _editionId, _owner);
    return cardIds;
  }

  /// @dev An internal method that creates a new card and stores it.
  ///  Emits both a CardMinted and a Transfer event.
  /// @param _playerBbrefId The BBREF ID of the player represented by the card
  /// @param _editionId The CBBC Edition ID that the card belongs to
  /// @param _owner The card owner
  function _mintCard(
    string _playerBbrefId,
    uint16 _editionId,
    address _owner
  )
    internal
    returns (uint256)
  {
    uint16 seriesNumber = ++mintedCountForPlayerBbrefIdAndEditionId[_playerBbrefId][_editionId];
    Card memory newCard = Card({
      mintTime: uint64(now),
      playerBbrefId: _playerBbrefId,
      editionId: _editionId,
      seriesNumber: seriesNumber
    });
    uint256 newCardId = cards.push(newCard) - 1;
    emit CardMinted(_playerBbrefId, _editionId, newCardId, _owner);
    _mint(_owner, newCardId);
    return newCardId;
  }

  /// @dev Returns the API URL for a given token Id.
  /// see: https://docs.opensea.io/docs/2-adding-metadata
  function tokenURI(uint256 _tokenId) public view returns (string) {
    string memory _id = uint2str(_tokenId);
    return strConcat(API_BASE_URI, _id);
  }

  /// @dev Returns the player BB ref id, series number and series total for a given token Id.
  /// see: https://docs.opensea.io/docs/2-adding-metadata
  function seriesInfo(uint256 _tokenId) public view returns (string, uint16, uint16, uint16) {
    Card memory card = cards[_tokenId];
    return (card.playerBbrefId, card.editionId, card.seriesNumber, mintedCountForPlayerBbrefIdAndEditionId[card.playerBbrefId][card.editionId]);
  }

  // String helpers below were taken from Oraclize.
  // https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.4.sol

  function strConcat(string _a, string _b) internal pure returns (string) {
    bytes memory _ba = bytes(_a);
    bytes memory _bb = bytes(_b);
    string memory ab = new string(_ba.length + _bb.length);
    bytes memory bab = bytes(ab);
    uint k = 0;
    for (uint i = 0; i < _ba.length; i++) bab[k++] = _ba[i];
    for (i = 0; i < _bb.length; i++) bab[k++] = _bb[i];
    return string(bab);
  }

  function uint2str(uint i) internal pure returns (string) {
    if (i == 0) return "0";
    uint j = i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len - 1;
    while (i != 0) {
      bstr[k--] = byte(48 + i % 10);
      i /= 10;
    }
    return string(bstr);
  }

}
