/*
program drop TelegramMain 
program drop TelegramSetup 
program drop telegram
*/
* ==============================================================================
* test_telegram.do - Comprehensive Test Suite for the telegram package
* ==============================================================================

version 17
set more off
clear all

di as txt "{hline 78}"
di as res "Initiating telegram test suite. Pour yourself a coffee. This takes a minute."
di as txt "{hline 78}"

*------------------------------------------------------------------
* Preconditions
*------------------------------------------------------------------
capture which telegram
if _rc {
    di as err "CRITICAL: The 'telegram' command is not installed or not in your ADOPATH."
    di as err "Please run 'net install telegram' or point Stata to your local files."
    exit 199
}

* Check if credentials exist (either globally or in the setup config)
local has_creds 0
if `"$MSG_BOT_TOKEN"' != "" & `"$MSG_CHAT_ID"' != "" local has_creds 1
capture confirm file "`c(sysdir_personal)'telegram_config.txt"
if _rc == 0 local has_creds 1

if !`has_creds' {
    di as err "CRITICAL: No Telegram credentials found."
    di as err "Run 'telegram setup' first so the tests know where to send the output."
    exit 198
}

*------------------------------------------------------------------
* Helper: Run one test, evaluate RC, and enforce rate limits
*------------------------------------------------------------------
capture program drop _telegram_test
program define _telegram_test
    version 17
    // Changed TITLE to standard string to strip outer quotes automatically
    syntax , TITLE(string) CMD(string asis) [EXPECT(integer 0)]

    di as txt _n "{hline 78}"
    // Wrap display strings in compound quotes to prevent r(111) variable errors
    di as txt `"TEST: `title'"'
    di as txt `"> `cmd'"'

    // Safely strip outer compound quotes or standard quotes from the command string
    if ustrlen(`"`cmd'"') >= 4 ///
        & usubstr(`"`cmd'"', 1, 2) == char(96) + char(34) ///
        & usubstr(`"`cmd'"', -2, 2) == char(34) + char(39) {
        local cmd = usubstr(`"`cmd'"', 3, ustrlen(`"`cmd'"') - 4)
    }
    else if ustrlen(`"`cmd'"') >= 2 ///
        & usubstr(`"`cmd'"', 1, 1) == char(34) ///
        & usubstr(`"`cmd'"', -1, 1) == char(34) {
        local cmd = usubstr(`"`cmd'"', 2, ustrlen(`"`cmd'"') - 2)
    }

    // Execute and capture
    capture noisily `cmd'
    local rc = _rc

    if `rc' == `expect' {
        di as res "  [PASS] Behaved as expected (RC = `rc')."
    }
    else {
        di as err "  [FAIL] Expected RC `expect', but observed RC `rc'."
    }
    
    // Sleep 2 seconds to avoid irritating the Telegram API rate limits
    sleep 2000
end

*------------------------------------------------------------------
* Build Temporary Test Assets
*------------------------------------------------------------------
di as txt _n "Generating test assets (graphs, fake files, and massive strings)..."

local img_valid "test_valid.png"
local img_unsupp "test_unsupported.eps"
local img_fake "test_fake.jpg"

// 1. Valid PNG
sysuse auto, clear
quietly scatter price mpg, title("Test Scatter")
quietly graph export "`img_valid'", as(png) replace

// 2. Unsupported format (EPS)
quietly graph export "`img_unsupp'", as(eps) replace

// 3. Fake/corrupted image (text pretending to be binary)
tempname fh
file open `fh' using "`img_fake'", write text replace
file write `fh' "This is just text data masquerading as a JPG. The API should reject this."
file close `fh'

// 4. Invalid credentials for API rejection
local badtoken  "123456:ABCdefGhijkLMNopqrstUVwxYZ_12345"
local badchat   "@definitely_not_a_real_channel_987654321"

// 5. Build a massive 4095-character padding string for boundary testing
local padding ""
forvalues i = 1/4095 {
    local padding "`padding'A"
}
local boundary_payload `"`padding'🚀BBB"'

// 6. Build a 1025-character caption (1 character over Telegram's image limit)
local long_cap "`padding'"
local long_cap = usubstr(`"`long_cap'"', 1, 1025)

*------------------------------------------------------------------
* GROUP 1: Local Preflight Failures (Expected to crash gracefully)
*------------------------------------------------------------------
_telegram_test, title("Blank text only") ///
    cmd(`"telegram "    ""') expect(198)

_telegram_test, title("Invalid token syntax") ///
    cmd(`"telegram "bad token syntax", token("bad_token_no_colon")"') expect(198)

_telegram_test, title("Invalid chatid syntax") ///
    cmd(`"telegram "bad chat syntax", chatid("invalid chat space")"') expect(198)

_telegram_test, title("Invalid timeout parameter") ///
    cmd(`"telegram "bad timeout", connecttimeout(-1)"') expect(198)

_telegram_test, title("Missing figure file") ///
    cmd(`"telegram, figure("ghost_file_does_not_exist.png")"') expect(601)

_telegram_test, title("Unsupported figure extension (.eps)") ///
    cmd(`"telegram, figure("`img_unsupp'")"') expect(198)

_telegram_test, title("Caption Limit Exceeded (1025 chars)") ///
    cmd(`"telegram "`long_cap'", figure("`img_valid'")"') expect(198)

_telegram_test, title("Bad curl binary path") ///
    cmd(`"telegram "bad curl", curlcmd("definitely_not_curl_binary")"') expect(198)

*------------------------------------------------------------------
* GROUP 2: API Rejections (Valid syntax, but Telegram says no)
*------------------------------------------------------------------
_telegram_test, title("API rejection: Wrong Token") ///
    cmd(`"telegram "unauthorized test", token("`badtoken'")"') expect(22)

_telegram_test, title("API rejection: Wrong Chat ID") ///
    cmd(`"telegram "chat not found test", chatid("`badchat'")"') expect(22)

_telegram_test, title("API rejection: Corrupted/Fake Image") ///
    cmd(`"telegram "Fake JPG test", figure("`img_fake'")"') expect(22)

*------------------------------------------------------------------
* GROUP 3: Success Paths (If these fail, we have a real problem)
*------------------------------------------------------------------
_telegram_test, title("Standard ASCII") ///
    cmd(`"telegram "Hello World! This is a standard test.", quiet"') expect(0)

_telegram_test, title("Pipes converted to line breaks") ///
    cmd(`"telegram "Line 1 || Line 2 || Line 3", quiet"') expect(0)

_telegram_test, title("notrimpipe branch") ///
    cmd(`"telegram "Line 1 || Line 2", notrimpipe quiet"') expect(0)

_telegram_test, title("Complex Emojis (ZWJ)") ///
    cmd(`"telegram "Space: 🚀 | Flag: 🇺🇳 | Family: 👨‍👩‍👧‍👦 | Ninja: 🥷🏿", quiet"') expect(0)

_telegram_test, title("CJK Characters") ///
    cmd(`"telegram "Chinese: 測試 || Japanese: テスト || Korean: 테스트", quiet"') expect(0)

_telegram_test, title("RTL Languages (Arabic / Hebrew)") ///
    cmd(`"telegram "Arabic: رسالة اختبار || Hebrew: הודעת בדיקה", quiet"') expect(0)

_telegram_test, title("Quotes, Escaping, and Syntax Collisions") ///
    cmd(`"telegram `"She said, "Look at this || break!" and used 'single quotes', an @ symbol, and a tilde ~."', quiet"') expect(0)

_telegram_test, title("4096-Character Unicode Boundary Split") ///
    cmd(`"telegram `"`boundary_payload'"', quiet"') expect(0)

_telegram_test, title("Valid Figure without Caption") ///
    cmd(`"telegram, figure("`img_valid'") quiet"') expect(0)

_telegram_test, title("Valid Figure with Caption") ///
    cmd(`"telegram "Figure caption test", figure("`img_valid'") quiet"') expect(0)

*------------------------------------------------------------------
* Cleanup
*------------------------------------------------------------------
capture erase "`img_valid'"
capture erase "`img_unsupp'"
capture erase "`img_fake'"

*------------------------------------------------------------------
* Manual Transport-Failure Tests
*------------------------------------------------------------------
di as txt _n "{hline 78}"
di as txt "AUTOMATED SUITE COMPLETE."
di as txt "If you saw all [PASS] tags, grab that wine."
di as txt "{hline 78}"
di as txt "MANUAL OFFLINE TESTS (Optional):"
di as txt "1) Disconnect your Wi-Fi / ethernet cable."
di as txt "2) Run the two commands below manually in the Stata console."
di as txt "3) Stata should handle the curl timeout gracefully without crashing."
di as txt ""
di as res `"  capture noisily telegram "offline text test", debug"'
di as res `"  capture noisily telegram "offline figure test", figure("`img_valid'") debug"'
di as txt "{hline 78}"
