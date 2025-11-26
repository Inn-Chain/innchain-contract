// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title InnChain Booking Escrow
/// @notice Escrow booking + tokenized deposit untuk hotel dengan kelas kamar
contract InnChain is Ownable {
    IERC20 public stableToken;

    constructor(address _stableToken) Ownable(msg.sender) {
        require(_stableToken != address(0), "Invalid token");
        stableToken = IERC20(_stableToken);
    }

    // =====================
    // DATA STRUCTURES
    // =====================

    struct RoomClass {
        bool exists;
        string name;          // contoh: "Standard", "Deluxe", "Suite"
        uint256 pricePerNight;
    }

    struct Hotel {
        bool registered;
        address payable wallet;      // wallet penerima pembayaran
        uint256 classCount;          // total kelas
        mapping(uint256 => RoomClass) classes; // classId => RoomClass
    }

    struct Booking {
        address customer;
        uint256 hotelId;
        uint256 classId;
        uint256 nights;
        uint256 roomCost;        // harga kamar total (pricePerNight * nights)
        uint256 depositAmount;   // deposit yang dikunci
        bool paidRoom;
        bool roomReleased;       // roomCost sudah dikirim ke hotel
        bool depositReleased;    // deposit sudah di-handle (refund/charge)
    }

    mapping(uint256 => Hotel) private _hotels;
    mapping(uint256 => Booking) private _bookings;

    uint256 public hotelCount;
    uint256 public bookingCount;

    // =====================
    // EVENTS
    // =====================

    event HotelRegistered(uint256 indexed hotelId, address wallet);
    event RoomClassAdded(uint256 indexed hotelId, uint256 indexed classId, string name, uint256 pricePerNight);
    event RoomClassUpdated(uint256 indexed hotelId, uint256 indexed classId, string name, uint256 pricePerNight);
    event BookingCreated(uint256 indexed bookingId, uint256 indexed hotelId, uint256 indexed classId, address customer, uint256 roomCost, uint256 depositAmount);
    event RoomPaymentReleased(uint256 indexed bookingId, uint256 amountToHotel);
    event DepositRefunded(uint256 indexed bookingId, uint256 amountToCustomer);
    event DepositCharged(uint256 indexed bookingId, uint256 amountToHotel, uint256 amountToCustomer);
    event FullRefund(uint256 indexed bookingId, uint256 totalRefund);

    // =====================
    // MODIFIERS
    // =====================

    modifier onlyHotelOwner(uint256 hotelId) {
        require(_hotels[hotelId].registered, "Hotel: not found");
        require(_hotels[hotelId].wallet == msg.sender, "Hotel: not owner");
        _;
    }

    // =====================
    // HOTEL MANAGEMENT
    // =====================

    /// @notice Register hotel baru
    /// @param wallet alamat wallet hotel untuk menerima pembayaran
    function registerHotel(address payable wallet) external returns (uint256) {
        require(wallet != address(0), "Hotel: invalid wallet");

        hotelCount++;
        Hotel storage h = _hotels[hotelCount];
        h.registered = true;
        h.wallet = wallet;

        emit HotelRegistered(hotelCount, wallet);
        return hotelCount;
    }

    /// @notice Tambah kelas kamar baru di hotel
    /// @param hotelId id hotel
    /// @param name nama kelas, contoh "Deluxe"
    /// @param pricePerNight harga per malam dalam stableToken (misal mUSD)
    function addRoomClass(
        uint256 hotelId,
        string memory name,
        uint256 pricePerNight
    ) external onlyHotelOwner(hotelId) returns (uint256) {
        require(bytes(name).length > 0, "Class: empty name");
        require(pricePerNight > 0, "Class: price must > 0");

        Hotel storage h = _hotels[hotelId];
        h.classCount++;

        h.classes[h.classCount] = RoomClass({
            exists: true,
            name: name,
            pricePerNight: pricePerNight
        });

        emit RoomClassAdded(hotelId, h.classCount, name, pricePerNight);
        return h.classCount;
    }

    /// @notice Update nama & harga kelas kamar
    function updateRoomClass(
        uint256 hotelId,
        uint256 classId,
        string memory name,
        uint256 newPricePerNight
    ) external onlyHotelOwner(hotelId) {
        Hotel storage h = _hotels[hotelId];
        RoomClass storage rc = h.classes[classId];

        require(rc.exists, "Class: not found");
        require(bytes(name).length > 0, "Class: empty name");
        require(newPricePerNight > 0, "Class: price must > 0");

        rc.name = name;
        rc.pricePerNight = newPricePerNight;

        emit RoomClassUpdated(hotelId, classId, name, newPricePerNight);
    }

    // =====================
    // BOOKING + ESCROW
    // =====================

    /// @notice Buat booking baru + bayar room + deposit
    /// @param hotelId ID hotel
    /// @param classId ID kelas kamar
    /// @param nights jumlah malam
    /// @param depositAmount jumlah deposit yang dikunci (stableToken)
    function createBooking(
        uint256 hotelId,
        uint256 classId,
        uint256 nights,
        uint256 depositAmount
    ) external returns (uint256) {
        Hotel storage h = _hotels[hotelId];
        require(h.registered, "Hotel: invalid");
        require(nights > 0, "Booking: nights must > 0");

        RoomClass storage rc = h.classes[classId];
        require(rc.exists, "Class: invalid");

        uint256 roomCost = rc.pricePerNight * nights;
        uint256 total = roomCost + depositAmount;
        require(total > 0, "Booking: total must > 0");

        // Pindahin token dari customer ke kontrak (escrow)
        bool ok = stableToken.transferFrom(msg.sender, address(this), total);
        require(ok, "Token: transferFrom failed");

        bookingCount++;
        _bookings[bookingCount] = Booking({
            customer: msg.sender,
            hotelId: hotelId,
            classId: classId,
            nights: nights,
            roomCost: roomCost,
            depositAmount: depositAmount,
            paidRoom: true,
            roomReleased: false,
            depositReleased: false
        });

        emit BookingCreated(bookingCount, hotelId, classId, msg.sender, roomCost, depositAmount);
        return bookingCount;
    }

    /// @notice Hotel mengkonfirmasi check-in → roomCost dibayar ke hotel
    function confirmCheckIn(uint256 bookingId) external {
        Booking storage b = _bookings[bookingId];
        require(b.customer != address(0), "Booking: not found");

        Hotel storage h = _hotels[b.hotelId];
        require(msg.sender == h.wallet, "Hotel: only wallet");
        require(b.paidRoom, "Booking: not paid");
        require(!b.roomReleased, "Booking: room already released");

        b.roomReleased = true;

        bool ok = stableToken.transfer(h.wallet, b.roomCost);
        require(ok, "Token: transfer to hotel failed");

        emit RoomPaymentReleased(bookingId, b.roomCost);
    }

    /// @notice Refund deposit full ke customer (tidak ada charge)
    function refundDeposit(uint256 bookingId) external {
        Booking storage b = _bookings[bookingId];
        require(b.customer != address(0), "Booking: not found");

        Hotel storage h = _hotels[b.hotelId];
        require(
            msg.sender == h.wallet || msg.sender == owner(),
            "Deposit: not authorized"
        );
        require(!b.depositReleased, "Deposit: already handled");

        b.depositReleased = true;

        if (b.depositAmount > 0) {
            bool ok = stableToken.transfer(b.customer, b.depositAmount);
            require(ok, "Token: transfer refund failed");
        }

        emit DepositRefunded(bookingId, b.depositAmount);
    }

    /// @notice Hotel mengambil sebagian/semua deposit (kerusakan, minibar, dll)
    /// @param amount jumlah yang diambil hotel dari deposit
    function chargeDeposit(uint256 bookingId, uint256 amount) external {
        Booking storage b = _bookings[bookingId];
        require(b.customer != address(0), "Booking: not found");

        Hotel storage h = _hotels[b.hotelId];
        require(msg.sender == h.wallet, "Deposit: only hotel");
        require(!b.depositReleased, "Deposit: already handled");
        require(amount <= b.depositAmount, "Deposit: too much");

        b.depositReleased = true;

        uint256 toHotel = amount;
        uint256 toCustomer = b.depositAmount - amount;

        if (toHotel > 0) {
            bool ok1 = stableToken.transfer(h.wallet, toHotel);
            require(ok1, "Token: transfer to hotel failed");
        }

        if (toCustomer > 0) {
            bool ok2 = stableToken.transfer(b.customer, toCustomer);
            require(ok2, "Token: transfer to customer failed");
        }

        emit DepositCharged(bookingId, toHotel, toCustomer);
    }

    /// @notice Refund full (room + deposit) ke customer (misal booking dibatalkan sebelum check-in)
    function fullRefund(uint256 bookingId) external {
        Booking storage b = _bookings[bookingId];
        require(b.customer != address(0), "Booking: not found");

        Hotel storage h = _hotels[b.hotelId];
        require(
            msg.sender == b.customer ||
            msg.sender == h.wallet ||
            msg.sender == owner(),
            "Refund: not authorized"
        );
        require(!b.roomReleased, "Refund: already checked-in");

        uint256 totalRefund = b.roomCost + b.depositAmount;

        b.roomReleased = true;
        b.depositReleased = true;

        if (totalRefund > 0) {
            bool ok = stableToken.transfer(b.customer, totalRefund);
            require(ok, "Token: refund failed");
        }

        emit FullRefund(bookingId, totalRefund);
    }

    // =====================
    // VIEW HELPERS 
    // =====================

    function getHotel(uint256 hotelId)
        external
        view
        returns (bool registered, address wallet, uint256 classCount)
    {
        Hotel storage h = _hotels[hotelId];
        return (h.registered, h.wallet, h.classCount);
    }

    function getRoomClass(uint256 hotelId, uint256 classId)
        external
        view
        returns (bool exists, string memory name, uint256 pricePerNight)
    {
        Hotel storage h = _hotels[hotelId];
        RoomClass storage rc = h.classes[classId];
        return (rc.exists, rc.name, rc.pricePerNight);
    }

    function getBooking(uint256 bookingId)
        external
        view
        returns (
            address customer,
            uint256 hotelId,
            uint256 classId,
            uint256 nights,
            uint256 roomCost,
            uint256 depositAmount,
            bool paidRoom,
            bool roomReleased,
            bool depositReleased
        )
    {
        Booking storage b = _bookings[bookingId];
        return (
            b.customer,
            b.hotelId,
            b.classId,
            b.nights,
            b.roomCost,
            b.depositAmount,
            b.paidRoom,
            b.roomReleased,
            b.depositReleased
        );
    }
}
