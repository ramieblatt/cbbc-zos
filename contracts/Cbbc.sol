pragma solidity ^0.4.21;
import "openzeppelin-zos/contracts/token/ERC721/MintableERC721Token.sol";
import "openzeppelin-zos/contracts/lifecycle/Pausable.sol";

/**
 * @title CBBC (Crypto Baseball Cards)
 */
contract Cbbc is MintableERC721Token, Pausable {

  /// @dev Emit this event whenever we set a new API Base URL (see setApiBaseUri below)
  event ApiBaseUriSet(string _api_base_url);
  /// @dev Emit this event whenever we mint a new edition (see mintEdition below)
  event EditionMinted(uint16 _newEditionId, string _name, uint16 _numCards);
  /// @dev Emit this event whenever we sell a new 5 pack of cards via ETH (see buyFivePackUsingEth below)
  event FivePackBoughtUsingEth(uint16 _editionId, address indexed _owner, uint256 _packPricePaid);
  /// @dev Emit this event whenever we sell a new 5 pack of cards via Fiat/Credit Card etc (see buyFivePackUsingFiatFor below)
  event FivePackBoughtUsingFiatFor(uint16 _editionId, address indexed _owner);
  /// @dev Emit this event whenever we sell a new 5 pack of cards (see buyFivePackFor below)
  event FivePackBoughtFor(uint16 _editionId, address indexed _owner);
  /// @dev Emit this event whenever we mint a new 5 pack of cards (see mintFivePack below)
  event FivePackMinted(uint16 _editionId, address indexed _owner);
  /// @dev Emit this event whenever we mint a new card (see _mintCard below)
  event CardMinted(bytes32 _playerBbrefId, bytes32 _cardType, uint16 _editionId, uint16 _seriesNumber, uint256 _cardId, address indexed _owner);
  /// @dev Emit this event whenever the contract fallback function is called
  event FallBackPaid(address indexed _sender, uint256 _value);

  /// @dev The struct representing the Crypto Baseball edition.
  struct Edition {
    // The timestamp at which this card was minted.
    uint64 mintTime;
    // The name of the Edition
    string name;
    // The number of cards in the Edition
    uint16 numCards;
  }

  /// @dev The struct representing the Crypto Baseball card.
  struct Card {
    // The timestamp at which this card was minted.
    uint64 mintTime;
    // The BBREF ID of the player represented by the card
    bytes32 playerBbrefId;
    // The type of card, ie "player", "pitcher", "manager"
    bytes32 cardType;
    // The CBBC Edition ID that the card belongs to
    uint16 editionId;
    // Cards for a given player and edition have a series number, which gets
    // incremented in sequence. If we mint 100 cards of a given player in an edition,
    // the 21st one to be minted has serialNumber = 21 of 100.
    uint16 seriesNumber;
  }

  /*** STORAGE ***/

  // @dev The default API Base URI
  string public constant API_BASE_URI = "http//api.crypto-baseball-cards.com/cards/";

  // @dev The API Base URI
  string public apiBaseUri;

  // @dev The default Pack Price in Wei, we start with ~0.05ETH
  uint256 public constant DEFAULT_PACK_PRICE = 50000000000000000;

  // @dev The Pack Price in Wei
  uint256 public packPrice;

  /// @dev All the editions that have been minted, indexed by editionId.
  Edition[] public editions;

  /// @dev All the cards that have been minted, indexed by cardId.
  Card[] public cards;

  /// @dev Keeps track of how many cards we have minted for a given edition
  mapping (uint16 => uint16) internal mintedCountForEditionId;

  /// @dev Keeps track of how many cards we have minted for a given player, card type and edition
  mapping (bytes32 => mapping (bytes32 => mapping (uint16 => uint16))) internal mintedCountForPlayerBbrefIdCardTypeAndEditionId;

  /// @dev Keeps track of how many card five packs we have sold for a given edition that are yet to be minted
  mapping (uint16 => uint16) internal soldUnmintedFivePackCountForEditionId;

  // @dev Mapping from owner to number of card five packs sold, to be minted
  mapping (address => mapping (uint16 => uint16)) internal soldUnmintedFivePackCountForOwnerAndEditionId;

  /// @dev We initialize with the standard params.
  /// @param _sender is the Contract owner.
  /// @param _name is the CBBC ERC721 token name.
  /// @param _symbol is the CBBC ERC721 token symbol.
  function initialize(address _sender, string _name, string _symbol) isInitializer("Cbbc", "0.1.0")  public {
    apiBaseUri = API_BASE_URI;
    packPrice = DEFAULT_PACK_PRICE;
    Ownable.initialize(_sender);
    ERC721Token.initialize(_name, _symbol);
  }

  /// @dev Allows the contract owner to set a new API Base URL.
  /// @param _apiBaseUri the new API Base URL
  function setApiBaseUri(
    string _apiBaseUri
  )
  external onlyOwner
  returns (string)
  {
    apiBaseUri = _apiBaseUri;
    return apiBaseUri;
  }

  /// @dev Allows the contract owner to set a new pack price in wei.
  /// @param _packPrice the new pack price
  function setPackPrice(
    uint256 _packPrice
  )
  external onlyOwner
  returns (uint256)
  {
    packPrice = _packPrice;
    return packPrice;
  }

  /// @dev Allows the contract owner to mint a new edition of cards.
  /// @param _name the name of the edition
  /// @param _numFivePacks the total number of card five packs in the edition
  function mintEdition(
    string _name,
    uint16 _numFivePacks
  )
  external onlyOwner
  returns (uint16)
  {
    return _mintEdition(_name, _numFivePacks);
  }

  /// @dev An internal method that creates a new card and stores it.
  /// Emits an EditionMinted event.
  /// @param _name the name of the edition
  /// @param _numFivePacks the total number of card five packs in the edition
  function _mintEdition(
    string _name,
    uint16 _numFivePacks
  )
  internal
  returns (uint16)
  {
    Edition memory newEdition = Edition({
      mintTime: uint64(now),
      name: _name,
      numCards: _numFivePacks*5
    });
    uint16 newEditionId = uint16(editions.push(newEdition) - 1);
    emit EditionMinted(newEditionId, _name, _numFivePacks*5);
    return newEditionId;
  }

  /// @dev Allows the contract owner to buy a five pack of cards on behalf of someone (for packs purchased not via ETH but using fiat, credit cards, etc).
  /// @param _editionId is the CBBC edition ID for the 5 new cards.
  /// @param _owner will be the pack's owner.
  function buyFivePackUsingFiatFor(
    uint16 _editionId,
    address _owner
  )
  external onlyOwner
  returns (uint16)
  {
    uint16 numFivePacksOwed = _buyFivePackFor(_editionId, _owner);
    emit FivePackBoughtUsingFiatFor(_editionId, _owner);
    return numFivePacksOwed;
  }

  /// @dev buyFivePack function, payable, requires amount paid to be more than packPrice.
  /// @param _editionId is the CBBC edition ID for the 5 new cards.
  function buyFivePackUsingEth(
    uint16 _editionId
  )
  public payable
  returns (uint16)
  {
    require(msg.value > packPrice);
    uint16 numFivePacksOwed = _buyFivePackFor(_editionId, msg.sender);
    emit FivePackBoughtUsingEth(_editionId, msg.sender, msg.value);
    return numFivePacksOwed;
  }

  /// @dev Allows the contract owner to buy a five pack of cards on behalf of someone (for packs purchased not via ETH but using fiat, credit cards, etc).
  /// @param _editionId is the CBBC edition ID for the 5 new cards.
  /// @param _owner will be the pack's owner.
  function _buyFivePackFor(
    uint16 _editionId,
    address _owner
  )
  internal
  returns (uint16)
  {
    require(_owner != address(this));
    require(checkEditionExists(_editionId));
    require(enoughUnmintedCardsToSellFivePack(_editionId));
    soldUnmintedFivePackCountForEditionId[_editionId] += 1;
    soldUnmintedFivePackCountForOwnerAndEditionId[_owner][_editionId] += 1;
    emit FivePackBoughtFor(_editionId, _owner);
    return soldUnmintedFivePackCountForOwnerAndEditionId[_owner][_editionId];
  }

  /// @dev Allows the contract owner to mint a pack of 5 cards.
  /// @param _playerBbrefIds are the player BBREF IDs for the 5 new card.
  /// @param _cardTypes are the card types ("player", "pitcher", "manager") for the 5 new cards.
  /// @param _editionId is the CBBC edition ID for the 5 new cards.
  /// @param _owner is the pack's owner.
  /// @return The 5 new card IDs.
  function mintFivePack(
    bytes32[5] _playerBbrefIds,
    bytes32[5] _cardTypes,
    uint16 _editionId,
    address _owner
  )
  external onlyOwner
  returns (uint256[5])
  {
    require(checkEditionExists(_editionId));
    Edition memory edition = editions[_editionId];
    assert(edition.numCards >= (mintedCountForEditionId[_editionId] + 5));
    assert(soldUnmintedFivePackCountForEditionId[_editionId] >= 1);
    assert(soldUnmintedFivePackCountForOwnerAndEditionId[_owner][_editionId] >= 1);
    mintedCountForEditionId[_editionId] += 5;
    soldUnmintedFivePackCountForEditionId[_editionId] -= 1;
    soldUnmintedFivePackCountForOwnerAndEditionId[_owner][_editionId] -= 1;
    uint256[5] memory cardIds;
    for(uint i = 0; i < 5; ++i)
    {
      cardIds[i] = _mintCard(_playerBbrefIds[i], _cardTypes[i], _editionId, _owner);
    }
    emit FivePackMinted(_editionId, _owner);
    return cardIds;
  }

  /// @dev An internal method that creates a new card and stores it.
  ///  Emits both a CardMinted and a Transfer event.
  /// @param _editionId The CBBC Edition ID that the card belongs to
  /// @param _owner The card owner
  function _mintCard(
    bytes32 _playerBbrefId,
    bytes32 _cardType,
    uint16 _editionId,
    address _owner
  )
    internal
    returns (uint256)
  {
    uint16 seriesNumber = ++mintedCountForPlayerBbrefIdCardTypeAndEditionId[_playerBbrefId][_cardType][_editionId];
    Card memory newCard = Card({
      mintTime: uint64(now),
      playerBbrefId: _playerBbrefId,
      cardType: _cardType,
      editionId: _editionId,
      seriesNumber: seriesNumber
    });
    uint256 newCardId = cards.push(newCard) - 1;
    emit CardMinted(_playerBbrefId, _cardType, _editionId, seriesNumber, newCardId, _owner);
    _mint(_owner, newCardId);
    return newCardId;
  }

  /// @dev Returns the API URL for a given token Id.
  /// @param _tokenId The Token ID
  function tokenURI(uint256 _tokenId) public view returns (string) {
    require(checkCardExists(_tokenId));
    string memory _id = uint2str(_tokenId);
    return strConcat(apiBaseUri, _id);
  }

  /// @dev Returns true if the edition with ID _editionId exists.
  /// @param _editionId The CBBC Edition ID to check
  function checkEditionExists(uint16 _editionId) public view returns(bool){
    if((_editionId >= 0) && (_editionId < editions.length)) {
      return true;
    } else {
      return false;
    }
  }

  /// @dev Returns the number of editions.
  function numberOfEditions() public view returns(uint256){
    return editions.length;
  }

  /// @dev Returns the edition name, number of cards, minted count of cards for the edition, and pack price for a given _editionId.
  /// @param _editionId The CBBC Edition ID to check
  function editionInfo(uint16 _editionId) public view returns (string, uint16, uint16, bool, uint16) {
    require(checkEditionExists(_editionId));
    Edition memory edition = editions[_editionId];
    return (edition.name, edition.numCards, mintedCountForEditionId[_editionId], enoughUnmintedCardsToSellFivePack(_editionId), soldUnmintedFivePackCountForEditionId[_editionId]);
  }

  /// @dev Returns true if the card with ID _cardId exists.
  /// @param _cardId The Card ID
  function checkCardExists(uint256 _cardId) public view returns(bool){
    if((_cardId >= 0) && (_cardId < cards.length)) {
      return true;
    } else {
      return false;
    }
  }

  /// @dev Returns the number of minted cards.
  function numberOfCards() public view returns (uint256){
    return cards.length;
  }

  /// @dev Returns the edition id, minted card count for the edition and tokenURI for a given card/token Id.
  /// @param _cardId The Card ID
  function cardInfo(uint256 _cardId) public view returns (bytes32, bytes32, uint16, uint16, uint16) {
    require(checkCardExists(_cardId));
    Card memory card = cards[_cardId];
    return (card.playerBbrefId, card.cardType, card.editionId, card.seriesNumber, mintedCountForPlayerBbrefIdCardTypeAndEditionId[card.playerBbrefId][card.cardType][card.editionId]);
  }

  /// @dev Withdraw remaining contract balance to owner.
  function withdraw() external onlyOwner {
    msg.sender.transfer(address(this).balance);
  }

  /// @dev Returns true if the edition with ID _editionId exists.
  /// @param _editionId The CBBC Edition ID to check
  function enoughUnmintedCardsToSellFivePack(uint16 _editionId) public view returns(bool){
    require(checkEditionExists(_editionId));
    Edition memory edition = editions[_editionId];
    uint16 _numUnmintedCardsInEdition = (edition.numCards - mintedCountForEditionId[_editionId]);
    if (_numUnmintedCardsInEdition >= (soldUnmintedFivePackCountForEditionId[_editionId] + 1)*5 ) {
      return true;
    } else {
      return false;
    }
  }

  /// @dev Fallback function, require no data and just emit a FallBackPaid event.
  function () public payable {
    require(msg.data.length == 0);
    emit FallBackPaid(msg.sender, msg.value);
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
