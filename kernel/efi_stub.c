// UEFI x86-64 loader for KrumpyOS. The EFI application loads the flat kernel
// payload from the same FAT volume and transfers control while already in
// firmware-provided long mode.

#define EFIAPI __attribute__((ms_abi))

typedef unsigned long long size_t;

typedef unsigned char UINT8;
typedef unsigned short UINT16;
typedef unsigned int UINT32;
typedef unsigned long long UINT64;
typedef UINT64 UINTN;
typedef UINT64 EFI_STATUS;
typedef void *EFI_HANDLE;
typedef void *EFI_EVENT;
typedef UINT16 CHAR16;

typedef struct {
    UINT32 Data1;
    UINT16 Data2;
    UINT16 Data3;
    UINT8 Data4[8];
} EFI_GUID;

#define EFI_SUCCESS 0ULL
#define EFI_ERROR 1ULL
#define EFI_FILE_MODE_READ 0x0000000000000001ULL
#define EFI_FILE_MODE_WRITE 0x0000000000000002ULL
#define EFI_ALLOCATE_ANY_PAGES 0
#define EFI_ALLOCATE_MAX_ADDRESS 2
#define EFI_ALLOCATE_ADDRESS 3
#define EFI_LOADER_DATA 2

#define EFI_OPEN_PROTOCOL_BY_HANDLE_PROTOCOL 0x0000000000000008ULL
#define EFI_OPEN_PROTOCOL_GET_PROTOCOL 0x0000000000000000ULL

typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;
typedef EFI_STATUS (EFIAPI *EFI_TEXT_STRING)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, CHAR16 *String);

typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
    EFI_TEXT_STRING OutputString;
} EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;

typedef struct _EFI_BOOT_SERVICES EFI_BOOT_SERVICES;
typedef EFI_STATUS (EFIAPI *EFI_BOOT_ALLOCATE_PAGES)(UINT32 Type, UINT32 MemoryType, UINTN Pages, UINT64 *Memory);
typedef EFI_STATUS (EFIAPI *EFI_BOOT_HANDLE_PROTOCOL)(EFI_HANDLE Handle, EFI_GUID *Protocol, void **Interface);
typedef struct _EFI_BOOT_SERVICES {
    UINT8 Header[24];
    void *RaiseTpl;
    void *RestoreTpl;
    EFI_BOOT_ALLOCATE_PAGES AllocatePages;
    void *FreePages;
    void *GetMemoryMap;
    void *AllocatePool;
    void *FreePool;
    void *CreateEvent;
    void *SetTimer;
    void *WaitForEvent;
    void *SignalEvent;
    void *CloseEvent;
    void *CheckEvent;
    void *InstallProtocolInterface;
    void *ReinstallProtocolInterface;
    void *UninstallProtocolInterface;
    EFI_BOOT_HANDLE_PROTOCOL HandleProtocol;
} EFI_BOOT_SERVICES;

typedef struct {
    UINT8 Header[24];
    CHAR16 *FirmwareVendor;
    UINT32 FirmwareRevision;
    UINT32 _FirmwarePadding;
    EFI_HANDLE ConsoleInHandle;
    void *ConIn;
    EFI_HANDLE ConsoleOutHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *ConOut;
    EFI_HANDLE StandardErrorHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *StdErr;
    void *RuntimeServices;
    EFI_BOOT_SERVICES *BootServices;
} EFI_SYSTEM_TABLE;

typedef struct {
    UINT32 Revision;
    EFI_HANDLE ParentHandle;
    EFI_SYSTEM_TABLE *SystemTable;
    EFI_HANDLE DeviceHandle;
} EFI_LOADED_IMAGE_PROTOCOL;

typedef struct _EFI_FILE_PROTOCOL EFI_FILE_PROTOCOL;
typedef EFI_STATUS (EFIAPI *EFI_FILE_OPEN)(EFI_FILE_PROTOCOL *This,
    EFI_FILE_PROTOCOL **NewHandle,
    CHAR16 *FileName,
    UINT64 OpenMode,
    UINT64 Attributes);
typedef EFI_STATUS (EFIAPI *EFI_FILE_CLOSE)(EFI_FILE_PROTOCOL *This);
typedef EFI_STATUS (EFIAPI *EFI_FILE_READ)(EFI_FILE_PROTOCOL *This,
    UINTN *BufferSize,
    void *Buffer);
typedef struct _EFI_FILE_PROTOCOL {
    UINT64 Revision;
    EFI_FILE_OPEN Open;
    EFI_FILE_CLOSE Close;
    void *Delete;
    EFI_FILE_READ Read;
} EFI_FILE_PROTOCOL;

typedef struct {
    UINT64 Revision;
    EFI_STATUS (EFIAPI *OpenVolume)(void *This, EFI_FILE_PROTOCOL **Root);
} EFI_SIMPLE_FILE_SYSTEM_PROTOCOL;

static const EFI_GUID gEfiLoadedImageProtocolGuid = { 0x5b1b31a1, 0x9562, 0x11d2, { 0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b } };
static const EFI_GUID gEfiSimpleFileSystemProtocolGuid = { 0x964e5b22, 0x6459, 0x11d2, { 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b } };

void *memcpy(void *dest, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}

static void SerialByte(UINT8 value) {
    __asm__ volatile ("outb %0, %1" : : "a"(value), "Nd"((UINT16)0x3F8));
}

static void SerialText(const char *text) {
    while (*text != '\0') {
        SerialByte((UINT8)*text++);
    }
}

static void EfiPrint(EFI_SYSTEM_TABLE *SystemTable, const CHAR16 *Text) {
    if (SystemTable != (void *)0 && SystemTable->ConOut != (void *)0 &&
        SystemTable->ConOut->OutputString != (void *)0) {
        SystemTable->ConOut->OutputString(SystemTable->ConOut, (CHAR16 *)Text);
    }
}

static void EfiPrintLn(EFI_SYSTEM_TABLE *SystemTable, const CHAR16 *Text) {
    EfiPrint(SystemTable, Text);
    EfiPrint(SystemTable, L"\r\n");
}

static char HexDigit(UINT8 v) {
    if (v < 10) return (char)('0' + v);
    return (char)('A' + (v - 10));
}

static void PrintBuffer(EFI_SYSTEM_TABLE *SystemTable, const void *buffer, UINTN length) {
    UINTN i;
    const UINT8 *bytes = (const UINT8 *)buffer;
    CHAR16 temp[64];
    UINTN pos = 0;
    for (i = 0; i < length && i < 32; ++i) {
        temp[pos++] = (CHAR16)HexDigit((UINT8)(bytes[i] >> 4));
        temp[pos++] = (CHAR16)HexDigit((UINT8)(bytes[i] & 0x0F));
        temp[pos++] = (CHAR16)' ';
    }
    temp[pos] = (CHAR16)0;
    EfiPrint(SystemTable, temp);
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_LOADED_IMAGE_PROTOCOL *loadedImage = (EFI_LOADED_IMAGE_PROTOCOL *)0;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs = (EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *)0;
    EFI_FILE_PROTOCOL *root = (EFI_FILE_PROTOCOL *)0;
    EFI_FILE_PROTOCOL *kernel = (EFI_FILE_PROTOCOL *)0;
    UINT64 kernel_addr = 0;
    UINT64 pages_needed = 16ULL;
    UINTN buffer_size = 32768;
    EFI_STATUS status;
    CHAR16 banner[] = L"KrumpyOS UEFI loader starting\r\n";
    CHAR16 msg[] = L"Loading kernel image in allocated pages\r\n";
    UINT8 *image = (UINT8 *)0;

    EfiPrintLn(SystemTable, banner);
    SerialText("EFI: start\n");

    if (SystemTable == (void *)0 || SystemTable->BootServices == (void *)0) {
        EfiPrintLn(SystemTable, L"no boot services\r\n");
        SerialText("EFI: no boot services\n");
        return EFI_ERROR;
    }

    status = SystemTable->BootServices->HandleProtocol(ImageHandle, (EFI_GUID *)&gEfiLoadedImageProtocolGuid, (void **)&loadedImage);
    if (status != EFI_SUCCESS || loadedImage == (void *)0) {
        EfiPrintLn(SystemTable, L"failed: loaded image handle\r\n");
        SerialText("EFI: loaded image failed\n");
        return EFI_ERROR;
    }

    status = SystemTable->BootServices->HandleProtocol(loadedImage->DeviceHandle, (EFI_GUID *)&gEfiSimpleFileSystemProtocolGuid, (void **)&fs);
    if (status != EFI_SUCCESS || fs == (void *)0) {
        EfiPrintLn(SystemTable, L"failed: filesystem handle\r\n");
        SerialText("EFI: filesystem failed\n");
        return EFI_ERROR;
    }

    status = fs->OpenVolume(fs, &root);
    if (status != EFI_SUCCESS || root == (void *)0) {
        EfiPrintLn(SystemTable, L"failed: root volume\r\n");
        SerialText("EFI: volume failed\n");
        return EFI_ERROR;
    }

    status = root->Open(root, &kernel, L"KRUMPYOS.BIN", EFI_FILE_MODE_READ, 0);
    if (status != EFI_SUCCESS || kernel == (void *)0) {
        EfiPrintLn(SystemTable, L"failed: KRUMPYOS.BIN\r\n");
        SerialText("EFI: kernel open failed\n");
        return EFI_ERROR;
    }

    status = SystemTable->BootServices->AllocatePages(
        EFI_ALLOCATE_ANY_PAGES, EFI_LOADER_DATA, (UINTN)pages_needed, &kernel_addr);
    if (status != EFI_SUCCESS) {
        EfiPrintLn(SystemTable, L"failed: allocate kernel pages\r\n");
        SerialText("EFI: allocation failed\n");
        return EFI_ERROR;
    }

    image = (UINT8 *)((UINT64)kernel_addr);
    EfiPrint(SystemTable, msg);
    SerialText("EFI: reading kernel\n");

    status = kernel->Read(kernel, &buffer_size, image);
    if (status != EFI_SUCCESS) {
        EfiPrintLn(SystemTable, L"failed: read kernel payload\r\n");
        SerialText("EFI: kernel read failed\n");
        return EFI_ERROR;
    }

    kernel->Close(kernel);
    root->Close(root);
    EfiPrintLn(SystemTable, L"Kernel payload loaded. Jumping to kernel entry.\r\n");
    SerialText("EFI: jumping to kernel\n");

    __asm__ volatile ("cli");
    ((void (*)(void))((UINT64)image))();
    EfiPrintLn(SystemTable, L"kernel handoff returned unexpectedly\r\n");
    return EFI_ERROR;
}
