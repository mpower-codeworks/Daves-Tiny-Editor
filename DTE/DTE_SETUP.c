/*
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DTECFG - external font configurator for Dave's Tiny Editor                 ;;
;;                                                                            ;;
;; The Crinkler payload remains untouched. SETUP owns these tail fields:      ;;
;;                                                                            ;;
;;   file offset  996..999   startup WM_SYSCOMMAND                            ;;
;;                           0000F120h = SC_RESTORE / Windowed                ;;
;;                           0000F030h = SC_MAXIMIZE                          ;;
;;   file offset 1000..1019  ANSI font face, NUL terminated                   ;;
;;   file offset 1020..1023  signed CreateFontA nHeight                       ;;
;;                                                                            ;;
;; DTE sends the startup command after installing its own WindowProc.         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

compile with TCC

*/

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string.h>

#define CF_SCREENFONTS          0x00000001
#define CF_INITTOLOGFONTSTRUCT  0x00000040
#define CF_FORCEFONTEXIST       0x00010000

typedef struct tagDTE_CHOOSEFONTA {
    DWORD       lStructSize;
    HWND        hwndOwner;
    HDC         hDC;
    LOGFONTA   *lpLogFont;
    INT         iPointSize;
    DWORD       Flags;
    COLORREF    rgbColors;
    LPARAM      lCustData;
    void       *lpfnHook;
    LPCSTR      lpTemplateName;
    HINSTANCE   hInstance;
    LPSTR       lpszStyle;
    WORD        nFontType;
    WORD        alignment;
    INT         nSizeMin;
    INT         nSizeMax;
} DTE_CHOOSEFONTA;

typedef BOOL (WINAPI *PFN_CHOOSEFONTA) (DTE_CHOOSEFONTA *);


#define DTE_NAME          "dte.exe"
#define DTE_SIZE          1024
#define DTE_CODE_MAX      996
#define WINDOW_MODE_OFF   996
#define WINDOW_WINDOWED   0x0000F120
#define WINDOW_MAXIMIZED  0x0000F030
#define FONT_FACE_OFF     1000
#define FONT_FACE_LEN     20
#define FONT_HEIGHT_OFF   1020

/*
;;;;;;;;;;;;;;;;;;
;; ShowMessage ;;
;;;;;;;;;;;;;;;;;;
*/
static void ShowMessage (LPCSTR text, UINT flags)
{
    MessageBoxA (0, text, "DTE Font", flags);
}

/*
;;;;;;;;;;;;;
;; OpenDTE ;;
;;;;;;;;;;;;;
*/
static HANDLE OpenDTE (void)
{
    return CreateFileA (
        DTE_NAME,
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ,
        0,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        0
    );
}

/*
;;;;;;;;;;;;;;;;
;; IsDTEImage ;;
;;;;;;;;;;;;;;;;
*/
static BOOL IsDTEImage (HANDLE hFile)
{
    BYTE id[4];
    DWORD got;

    SetFilePointer (hFile, 0, 0, FILE_BEGIN);

    if (!ReadFile (hFile, id, sizeof (id), &got, 0))
        return FALSE;

    if (got != sizeof (id))
        return FALSE;

    return id[0] == 'M' &&
           id[1] == 'Z' &&
           id[2] == '3' &&
           id[3] == '0';
}

/*
;;;;;;;;;;;;;;;;;;;;;
;; ReadCurrentFont ;;
;;;;;;;;;;;;;;;;;;;;;
*/
static void ReadCurrentFont (HANDLE hFile, LOGFONTA *lf)
{
    DWORD size;
    DWORD got;

    ZeroMemory (lf, sizeof (*lf));
    lstrcpyA (lf->lfFaceName, "courier");
    lf->lfHeight = -19;

    size = GetFileSize (hFile, 0);

    if (size != DTE_SIZE)
        return;

    SetFilePointer (hFile, FONT_FACE_OFF, 0, FILE_BEGIN);
    ReadFile (hFile, lf->lfFaceName, FONT_FACE_LEN, &got, 0);
    lf->lfFaceName[FONT_FACE_LEN - 1] = 0;

    SetFilePointer (hFile, FONT_HEIGHT_OFF, 0, FILE_BEGIN);
    ReadFile (hFile, &lf->lfHeight, sizeof (lf->lfHeight), &got, 0);

    if (!lf->lfFaceName[0]) {
        lstrcpyA (lf->lfFaceName, "courier");
        lf->lfHeight = -19;
    }
}

/*
;;;;;;;;;;;;;;;;;;;
;; ChooseDTEFont ;;
;;;;;;;;;;;;;;;;;;;
*/
static BOOL ChooseDTEFont (LOGFONTA *lf)
{
    DTE_CHOOSEFONTA cf;
    PFN_CHOOSEFONTA chooseFont;
    HMODULE hComdlg;
    BOOL result;

    hComdlg = LoadLibraryA ("comdlg32.dll");

    if (!hComdlg)
        return FALSE;

    chooseFont = (PFN_CHOOSEFONTA)
        GetProcAddress (hComdlg, "ChooseFontA");

    if (!chooseFont) {
        FreeLibrary (hComdlg);
        return FALSE;
    }

    ZeroMemory (&cf, sizeof (cf));
    cf.lStructSize = sizeof (cf);
    cf.lpLogFont = lf;
    cf.Flags = CF_INITTOLOGFONTSTRUCT |
               CF_FORCEFONTEXIST |
               CF_SCREENFONTS;

    result = chooseFont (&cf);
    FreeLibrary (hComdlg);

    return result;
}

/*
;;;;;;;;;;;;;;;;;;;;;;
;; ChooseWindowMode ;;
;;;;;;;;;;;;;;;;;;;;;;
*/
static BOOL ChooseWindowMode (DWORD *mode)
{
    int result;

    result = MessageBoxA (
        0,
        "Start DTE maximized?\n\n"
        "Yes = Maximized\n"
        "No  = Windowed",
        "DTE Startup",
        MB_YESNOCANCEL | MB_ICONQUESTION
    );

    if (result == IDCANCEL)
        return FALSE;

    if (result == IDYES)
        *mode = WINDOW_MAXIMIZED;
    else
        *mode = WINDOW_WINDOWED;

    return TRUE;
}

/*
;;;;;;;;;;;;;;;;;;
;; WriteSettings ;;
;;;;;;;;;;;;;;;;;;
*/
static BOOL WriteSettings (
    HANDLE hFile,
    const LOGFONTA *lf,
    DWORD windowMode
)
{
    CHAR face[FONT_FACE_LEN];
    DWORD size;
    DWORD wrote;
    LONG height;

    size = GetFileSize (hFile, 0);

    if (size > DTE_CODE_MAX && size != DTE_SIZE) {
        ShowMessage (
            "This DTE build reaches the SETUP configuration area.",
            MB_OK | MB_ICONERROR
        );
        return FALSE;
    }

    if (lstrlenA (lf->lfFaceName) >= FONT_FACE_LEN) {
        ShowMessage (
            "That font name is too long for DTE's 20-byte font slot.",
            MB_OK | MB_ICONERROR
        );
        return FALSE;
    }

    ZeroMemory (face, sizeof (face));
    lstrcpyA (face, lf->lfFaceName);
    height = lf->lfHeight;

    /*
    ;; Extend short Crinkler output to exactly 1024 bytes.
    */
    if (size < DTE_SIZE) {
        BYTE zero = 0;

        SetFilePointer (hFile, DTE_SIZE - 1, 0, FILE_BEGIN);

        if (!WriteFile (hFile, &zero, 1, &wrote, 0))
            return FALSE;
    }

    SetFilePointer (hFile, WINDOW_MODE_OFF, 0, FILE_BEGIN);

    if (!WriteFile (hFile, &windowMode, sizeof (windowMode), &wrote, 0))
        return FALSE;

    SetFilePointer (hFile, FONT_FACE_OFF, 0, FILE_BEGIN);

    if (!WriteFile (hFile, face, sizeof (face), &wrote, 0))
        return FALSE;

    SetFilePointer (hFile, FONT_HEIGHT_OFF, 0, FILE_BEGIN);

    if (!WriteFile (hFile, &height, sizeof (height), &wrote, 0))
        return FALSE;

    return TRUE;
}

/*
;;;;;;;;;;;;;
;; WinMain ;;
;;;;;;;;;;;;;
*/
int WINAPI WinMain (
    HINSTANCE hInstance,
    HINSTANCE hPrevInstance,
    LPSTR     lpCmdLine,
    int       nCmdShow
)
{
    HANDLE hFile;
    LOGFONTA lf;
    DWORD windowMode;

    (void) hInstance;
    (void) hPrevInstance;
    (void) lpCmdLine;
    (void) nCmdShow;

    hFile = OpenDTE ();

    if (hFile == INVALID_HANDLE_VALUE) {
        ShowMessage (
            "Put DTECFG.exe beside dte.exe and run it again.",
            MB_OK | MB_ICONERROR
        );
        return 1;
    }

    if (!IsDTEImage (hFile)) {
        CloseHandle (hFile);
        ShowMessage (
            "This is not the expected Crinkler 3.0 DTE image.",
            MB_OK | MB_ICONERROR
        );
        return 1;
    }

    ReadCurrentFont (hFile, &lf);

    if (!ChooseDTEFont (&lf)) {
        CloseHandle (hFile);
        return 0;
    }

    if (!ChooseWindowMode (&windowMode)) {
        CloseHandle (hFile);
        return 0;
    }

    if (!WriteSettings (hFile, &lf, windowMode)) {
        CloseHandle (hFile);
        ShowMessage (
            "The DTE settings could not be written.",
            MB_OK | MB_ICONERROR
        );
        return 1;
    }

    CloseHandle (hFile);

    ShowMessage (
        "DTE settings updated.",
        MB_OK | MB_ICONINFORMATION
    );

    return 0;
}
