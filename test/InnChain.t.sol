// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/InnChain.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC untuk testing
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract InnChainTest is Test {
    InnChain public innchain;
    MockUSDC public usdc;
    
    address public owner;
    address public hotel1Wallet;
    address public customer1;
    address public customer2;
    
    // Initial setup values
    uint256 constant INITIAL_HOTEL_COUNT = 4;
    uint256 constant INITIAL_CLASS_COUNT = 3;
    
    // Room class prices (from constructor)
    uint256 constant STANDARD_PRICE = 12 * 1e18;
    uint256 constant DELUXE_PRICE = 24 * 1e18;
    uint256 constant SUITE_PRICE = 35 * 1e18;
    
    function setUp() public {
        // Setup addresses
        owner = address(this);
        hotel1Wallet = makeAddr("hotel1");
        customer1 = makeAddr("customer1");
        customer2 = makeAddr("customer2");
        
        // Deploy MockUSDC
        usdc = new MockUSDC();
        
        // Deploy InnChain
        innchain = new InnChain(address(usdc));
        
        // Mint USDC to customers for testing
        usdc.mint(customer1, 10000 * 1e18);
        usdc.mint(customer2, 10000 * 1e18);
        
        // Approve InnChain to spend customer USDC
        vm.prank(customer1);
        usdc.approve(address(innchain), type(uint256).max);
        
        vm.prank(customer2);
        usdc.approve(address(innchain), type(uint256).max);
    }
    
    // =====================
    // CONSTRUCTOR TESTS
    // =====================
    
    function test_Constructor_InitialState() public view {
        assertEq(innchain.hotelCount(), INITIAL_HOTEL_COUNT);
        assertEq(innchain.roomClassCount(), INITIAL_CLASS_COUNT);
        assertEq(innchain.bookingCount(), 0);
    }
    
    function test_Constructor_RoomClasses() public view {
        (bool exists1, string memory name1, uint256 price1) = innchain.roomClasses(1);
        assertEq(exists1, true);
        assertEq(name1, "Standard");
        assertEq(price1, STANDARD_PRICE);
        
        (bool exists2, string memory name2, uint256 price2) = innchain.roomClasses(2);
        assertEq(exists2, true);
        assertEq(name2, "Deluxe");
        assertEq(price2, DELUXE_PRICE);
        
        (bool exists3, string memory name3, uint256 price3) = innchain.roomClasses(3);
        assertEq(exists3, true);
        assertEq(name3, "Suite");
        assertEq(price3, SUITE_PRICE);
    }
    
    function test_Constructor_Hotels() public view {
        (bool registered, string memory name, , uint256 classCount) = innchain.getHotel(1);
        assertEq(registered, true);
        assertEq(name, "Hotel Sakura");
        assertEq(classCount, 2);
        
        (registered, name, , classCount) = innchain.getHotel(2);
        assertEq(registered, true);
        assertEq(name, "Golden Dragon Resort");
        assertEq(classCount, 3);
    }
    
    // =====================
    // HOTEL MANAGEMENT TESTS
    // =====================
    
    function test_RegisterHotel_Success() public {
        uint256 newHotelId = innchain.registerHotel("Test Hotel", payable(hotel1Wallet));
        
        assertEq(newHotelId, INITIAL_HOTEL_COUNT + 1);
        
        (bool registered, string memory name, address wallet, uint256 classCount) = innchain.getHotel(newHotelId);
        assertEq(registered, true);
        assertEq(name, "Test Hotel");
        assertEq(wallet, hotel1Wallet);
        assertEq(classCount, 0);
    }
    
    function test_RegisterHotel_OnlyOwner() public {
        vm.prank(customer1);
        vm.expectRevert();
        innchain.registerHotel("Unauthorized Hotel", payable(customer1));
    }
    
    function test_RegisterHotel_InvalidWallet() public {
        vm.expectRevert("Hotel: invalid wallet");
        innchain.registerHotel("Invalid Hotel", payable(address(0)));
    }
    
    function test_RegisterHotel_EmptyName() public {
        vm.expectRevert("Hotel: empty name");
        innchain.registerHotel("", payable(hotel1Wallet));
    }
    
    function test_LinkHotelToClass_Success() public {
        uint256 hotelId = innchain.registerHotel("New Hotel", payable(hotel1Wallet));
        
        innchain.linkHotelToClass(hotelId, 1);
        
        uint256[] memory classes = innchain.getHotelClasses(hotelId);
        assertEq(classes.length, 1);
        assertEq(classes[0], 1);
    }
    
    function test_LinkHotelToClass_InvalidHotel() public {
        vm.expectRevert("Hotel: not found");
        innchain.linkHotelToClass(999, 1);
    }
    
    function test_LinkHotelToClass_InvalidClass() public {
        uint256 hotelId = innchain.registerHotel("New Hotel", payable(hotel1Wallet));
        
        vm.expectRevert("Class: not found");
        innchain.linkHotelToClass(hotelId, 999);
    }
    
    // =====================
    // ROOM CLASS TESTS
    // =====================
    
    function test_AddGlobalRoomClass_Success() public {
        uint256 newClassId = innchain.addGlobalRoomClass("Presidential Suite", 100 * 1e18);
        
        assertEq(newClassId, INITIAL_CLASS_COUNT + 1);
        
        (bool exists, string memory name, uint256 price) = innchain.roomClasses(newClassId);
        assertEq(exists, true);
        assertEq(name, "Presidential Suite");
        assertEq(price, 100 * 1e18);
    }
    
    function test_AddGlobalRoomClass_OnlyOwner() public {
        vm.prank(customer1);
        vm.expectRevert();
        innchain.addGlobalRoomClass("Unauthorized Class", 50 * 1e18);
    }
    
    function test_AddGlobalRoomClass_EmptyName() public {
        vm.expectRevert("Class: empty name");
        innchain.addGlobalRoomClass("", 50 * 1e18);
    }
    
    function test_AddGlobalRoomClass_ZeroPrice() public {
        vm.expectRevert("Class: price must > 0");
        innchain.addGlobalRoomClass("Free Room", 0);
    }
    
    // =====================
    // BOOKING TESTS
    // =====================
    
    function test_CreateBooking_Success() public {
        uint256 hotelId = 1;
        uint256 classId = 1;
        uint256 nights = 3;
        uint256 deposit = 10 * 1e18;
        
        uint256 expectedRoomCost = STANDARD_PRICE * nights;
        uint256 expectedTotal = expectedRoomCost + deposit;
        
        uint256 balanceBefore = usdc.balanceOf(customer1);
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(hotelId, classId, nights, deposit);
        
        assertEq(bookingId, 1);
        assertEq(innchain.bookingCount(), 1);
        assertEq(usdc.balanceOf(customer1), balanceBefore - expectedTotal);
        assertEq(usdc.balanceOf(address(innchain)), expectedTotal);
    }
    
    function test_CreateBooking_CheckDetails() public {
        uint256 nights = 3;
        uint256 deposit = 10 * 1e18;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, nights, deposit);
        
        (
            address customer,
            ,
            ,
            uint256 bNights,
            uint256 roomCost,
            uint256 depositAmount,
            bool paidRoom,
            bool roomReleased,
            bool depositReleased
        ) = innchain.getBooking(bookingId);
        
        assertEq(customer, customer1);
        assertEq(bNights, nights);
        assertEq(roomCost, STANDARD_PRICE * nights);
        assertEq(depositAmount, deposit);
        assertEq(paidRoom, true);
        assertEq(roomReleased, false);
        assertEq(depositReleased, false);
    }
    
    function test_CreateBooking_InvalidHotel() public {
        vm.prank(customer1);
        vm.expectRevert("Hotel: invalid");
        innchain.createBooking(999, 1, 3, 10 * 1e18);
    }
    
    function test_CreateBooking_InvalidClass() public {
        vm.prank(customer1);
        vm.expectRevert("Class: invalid");
        innchain.createBooking(1, 999, 3, 10 * 1e18);
    }
    
    function test_CreateBooking_ClassNotOffered() public {
        vm.prank(customer1);
        vm.expectRevert("Hotel: class not offered");
        innchain.createBooking(1, 3, 3, 10 * 1e18);
    }
    
    function test_CreateBooking_ZeroNights() public {
        vm.prank(customer1);
        vm.expectRevert("Booking: nights must > 0");
        innchain.createBooking(1, 1, 0, 10 * 1e18);
    }
    
    function test_CreateBooking_InsufficientBalance() public {
        address poorCustomer = makeAddr("poor");
        
        vm.prank(poorCustomer);
        usdc.approve(address(innchain), type(uint256).max);
        
        vm.prank(poorCustomer);
        vm.expectRevert();
        innchain.createBooking(1, 1, 3, 10 * 1e18);
    }
    
    // =====================
    // CHECK-IN TESTS
    // =====================
    
    function test_ConfirmCheckIn_Success() public {
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, 10 * 1e18);
        
        uint256 expectedRoomCost = STANDARD_PRICE * 3;
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        uint256 hotelBalanceBefore = usdc.balanceOf(hotelWallet);
        
        vm.prank(hotelWallet);
        innchain.confirmCheckIn(bookingId);
        
        assertEq(usdc.balanceOf(hotelWallet), hotelBalanceBefore + expectedRoomCost);
        
        (, , , , , , , bool roomReleased, ) = innchain.getBooking(bookingId);
        assertEq(roomReleased, true);
    }
    
    function test_ConfirmCheckIn_BookingNotFound() public {
        vm.expectRevert("Booking: not found");
        innchain.confirmCheckIn(999);
    }
    
    function test_ConfirmCheckIn_AlreadyReleased() public {
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, 10 * 1e18);
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        
        vm.prank(hotelWallet);
        innchain.confirmCheckIn(bookingId);
        
        vm.prank(hotelWallet);
        vm.expectRevert("Booking: room already released");
        innchain.confirmCheckIn(bookingId);
    }
    
    // =====================
    // DEPOSIT REFUND TESTS
    // =====================
    
    function test_RefundDeposit_Success() public {
        uint256 deposit = 10 * 1e18;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, deposit);
        
        uint256 customerBalanceBefore = usdc.balanceOf(customer1);
        
        innchain.refundDeposit(bookingId);
        
        assertEq(usdc.balanceOf(customer1), customerBalanceBefore + deposit);
        
        (, , , , , , , , bool depositReleased) = innchain.getBooking(bookingId);
        assertEq(depositReleased, true);
    }
    
    function test_RefundDeposit_AlreadyHandled() public {
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, 10 * 1e18);
        
        innchain.refundDeposit(bookingId);
        
        vm.expectRevert("Deposit: already handled");
        innchain.refundDeposit(bookingId);
    }
    
    function test_RefundDeposit_ZeroDeposit() public {
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, 0);
        
        innchain.refundDeposit(bookingId);
        
        (, , , , , , , , bool depositReleased) = innchain.getBooking(bookingId);
        assertEq(depositReleased, true);
    }
    
    // =====================
    // CHARGE DEPOSIT TESTS
    // =====================
    
    function test_ChargeDeposit_FullCharge() public {
        uint256 deposit = 10 * 1e18;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, deposit);
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        uint256 hotelBalanceBefore = usdc.balanceOf(hotelWallet);
        
        vm.prank(hotelWallet);
        innchain.chargeDeposit(bookingId, deposit);
        
        assertEq(usdc.balanceOf(hotelWallet), hotelBalanceBefore + deposit);
        
        (, , , , , , , , bool depositReleased) = innchain.getBooking(bookingId);
        assertEq(depositReleased, true);
    }
    
    function test_ChargeDeposit_PartialCharge() public {
        uint256 deposit = 10 * 1e18;
        uint256 chargeAmount = 6 * 1e18;
        uint256 refundAmount = deposit - chargeAmount;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, deposit);
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        uint256 hotelBalanceBefore = usdc.balanceOf(hotelWallet);
        uint256 customerBalanceBefore = usdc.balanceOf(customer1);
        
        vm.prank(hotelWallet);
        innchain.chargeDeposit(bookingId, chargeAmount);
        
        assertEq(usdc.balanceOf(hotelWallet), hotelBalanceBefore + chargeAmount);
        assertEq(usdc.balanceOf(customer1), customerBalanceBefore + refundAmount);
    }
    
    function test_ChargeDeposit_ExceedsAmount() public {
        uint256 deposit = 10 * 1e18;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, deposit);
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        
        vm.prank(hotelWallet);
        vm.expectRevert("Deposit: too much");
        innchain.chargeDeposit(bookingId, deposit + 1);
    }
    
    function test_ChargeDeposit_AlreadyHandled() public {
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, 10 * 1e18);
        
        innchain.refundDeposit(bookingId);
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        
        vm.prank(hotelWallet);
        vm.expectRevert("Deposit: already handled");
        innchain.chargeDeposit(bookingId, 5 * 1e18);
    }
    
    // =====================
    // FULL REFUND TESTS
    // =====================
    
    function test_FullRefund_Success() public {
        uint256 deposit = 10 * 1e18;
        uint256 nights = 3;
        uint256 expectedTotal = (STANDARD_PRICE * nights) + deposit;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, nights, deposit);
        
        uint256 customerBalanceBefore = usdc.balanceOf(customer1);
        
        innchain.fullRefund(bookingId);
        
        assertEq(usdc.balanceOf(customer1), customerBalanceBefore + expectedTotal);
    }
    
    function test_FullRefund_CheckFlags() public {
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, 10 * 1e18);
        
        innchain.fullRefund(bookingId);
        
        (, , , , , , , bool roomReleased, bool depositReleased) = innchain.getBooking(bookingId);
        assertEq(roomReleased, true);
        assertEq(depositReleased, true);
    }
    
    function test_FullRefund_AfterCheckIn() public {
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, 10 * 1e18);
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        
        vm.prank(hotelWallet);
        innchain.confirmCheckIn(bookingId);
        
        vm.expectRevert("Refund: already checked-in");
        innchain.fullRefund(bookingId);
    }
    
    // =====================
    // VIEW FUNCTION TESTS
    // =====================
    
    function test_GetAllHotelsWithDetails() public view {
        InnChain.HotelDetails[] memory hotels = innchain.getAllHotelsWithDetails();
        
        assertEq(hotels.length, INITIAL_HOTEL_COUNT);
        assertEq(hotels[0].id, 1);
        assertEq(hotels[0].name, "Hotel Sakura");
        assertEq(hotels[0].classCount, 2);
    }
    
    function test_GetAllHotelsWithDetails_Classes() public view {
        InnChain.HotelDetails[] memory hotels = innchain.getAllHotelsWithDetails();
        
        assertEq(hotels[0].classes.length, 2);
        assertEq(hotels[0].classes[0].name, "Standard");
        assertEq(hotels[0].classes[1].name, "Deluxe");
    }
    
    function test_GetCustomerBookings_Empty() public {
        vm.prank(customer1);
        InnChain.BookingDetails[] memory bookings = innchain.getCustomerBookings();
        
        assertEq(bookings.length, 0);
    }
    
    function test_GetCustomerBookings_WithBookings() public {
        vm.prank(customer1);
        innchain.createBooking(1, 1, 3, 10 * 1e18);
        
        vm.prank(customer1);
        innchain.createBooking(2, 2, 2, 5 * 1e18);
        
        vm.prank(customer1);
        InnChain.BookingDetails[] memory bookings = innchain.getCustomerBookings();
        
        assertEq(bookings.length, 2);
        assertEq(bookings[0].bookingId, 1);
        assertEq(bookings[0].hotelName, "Hotel Sakura");
    }
    
    function test_GetCustomerBookings_OnlyOwnBookings() public {
        vm.prank(customer1);
        innchain.createBooking(1, 1, 3, 10 * 1e18);
        
        vm.prank(customer2);
        innchain.createBooking(2, 2, 2, 5 * 1e18);
        
        vm.prank(customer1);
        InnChain.BookingDetails[] memory bookings1 = innchain.getCustomerBookings();
        assertEq(bookings1.length, 1);
        assertEq(bookings1[0].bookingId, 1);
        
        vm.prank(customer2);
        InnChain.BookingDetails[] memory bookings2 = innchain.getCustomerBookings();
        assertEq(bookings2.length, 1);
        assertEq(bookings2[0].bookingId, 2);
    }
    
    function test_GetAllRoomClasses() public view {
        (uint256[] memory ids, string[] memory names, uint256[] memory prices) = innchain.getAllRoomClasses();
        
        assertEq(ids.length, INITIAL_CLASS_COUNT);
        assertEq(names.length, INITIAL_CLASS_COUNT);
        assertEq(prices.length, INITIAL_CLASS_COUNT);
        
        assertEq(ids[0], 1);
        assertEq(names[0], "Standard");
        assertEq(prices[0], STANDARD_PRICE);
    }
    
    // =====================
    // INTEGRATION TESTS
    // =====================
    
    function test_Integration_HappyPath() public {
        uint256 deposit = 10 * 1e18;
        uint256 nights = 3;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, nights, deposit);
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        vm.prank(hotelWallet);
        innchain.confirmCheckIn(bookingId);
        
        innchain.refundDeposit(bookingId);
        
        (, , , , , , , bool roomReleased, bool depositReleased) = innchain.getBooking(bookingId);
        assertEq(roomReleased, true);
        assertEq(depositReleased, true);
    }
    
    function test_Integration_WithDamage() public {
        uint256 deposit = 10 * 1e18;
        uint256 damageCharge = 6 * 1e18;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, 3, deposit);
        
        (, , address hotelWallet, ) = innchain.getHotel(1);
        vm.prank(hotelWallet);
        innchain.confirmCheckIn(bookingId);
        
        uint256 hotelBalBefore = usdc.balanceOf(hotelWallet);
        uint256 custBalBefore = usdc.balanceOf(customer1);
        
        vm.prank(hotelWallet);
        innchain.chargeDeposit(bookingId, damageCharge);
        
        assertEq(usdc.balanceOf(hotelWallet), hotelBalBefore + damageCharge);
        assertEq(usdc.balanceOf(customer1), custBalBefore + (deposit - damageCharge));
    }
    
    function test_Integration_Cancellation() public {
        uint256 deposit = 10 * 1e18;
        uint256 nights = 3;
        uint256 expectedTotal = (STANDARD_PRICE * nights) + deposit;
        
        vm.prank(customer1);
        uint256 bookingId = innchain.createBooking(1, 1, nights, deposit);
        
        uint256 balBefore = usdc.balanceOf(customer1);
        
        innchain.fullRefund(bookingId);
        
        assertEq(usdc.balanceOf(customer1), balBefore + expectedTotal);
    }
}