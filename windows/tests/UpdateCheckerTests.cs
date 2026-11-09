// Checks UpdateChecker's version comparison and release parsing without the
// network. Run with windows\test.bat; exits 1 if any check fails.
using System;
using System.IO;
using System.Text;

namespace OpenHaze
{
    internal static class UpdateCheckerTests
    {
        private static int failures;

        private static void Expect(string name, bool ok)
        {
            Console.WriteLine((ok ? "PASS: " : "FAIL: ") + name);
            if (!ok) failures++;
        }

        private static Stream Json(string text)
        {
            return new MemoryStream(Encoding.UTF8.GetBytes(text));
        }

        private static bool IsUnreadable(string json)
        {
            try { UpdateChecker.ParseRelease(Json(json)); return false; }
            catch (UpdateResponseUnreadableException) { return true; }
        }

        private static int Main()
        {
            Expect("a newer patch is an update", UpdateChecker.IsNewer("v0.3.1", "0.3.0"));
            Expect("the same version is not an update", !UpdateChecker.IsNewer("v0.3.0", "0.3.0"));
            Expect("an older release is not an update", !UpdateChecker.IsNewer("v0.2.2", "0.3.0"));
            Expect("numbers compare numerically, not as text", UpdateChecker.IsNewer("v0.10.0", "0.9.0"));
            Expect("a release beats its own prerelease", UpdateChecker.IsNewer("v1.0.0", "1.0.0-rc.1"));
            Expect("a prerelease is older than its release", !UpdateChecker.IsNewer("v1.0.0-rc.1", "1.0.0"));
            Expect("build metadata is ignored", !UpdateChecker.IsNewer("v1.0.0+build.5", "1.0.0"));
            Expect("an unreadable tag is never an update", !UpdateChecker.IsNewer("latest", "0.3.0"));
            Expect("a development build is recognised", UpdateChecker.IsDevelopmentBuild("0.0.0-dev"));
            Expect("a release build is not a development build", !UpdateChecker.IsDevelopmentBuild("0.3.0"));

            var release = UpdateChecker.ParseRelease(Json(
                "{\"tag_name\":\"v0.3.0\",\"html_url\":\"https://github.com/jay739/openhaze/releases/tag/v0.3.0\"," +
                "\"draft\":false,\"assets\":[{\"name\":\"OpenHaze-0.3.0-Setup.exe\"}]}"));
            Expect("reads the tag and page from GitHub's reply",
                release.Tag == "v0.3.0" && release.PageUrl == "https://github.com/jay739/openhaze/releases/tag/v0.3.0");
            Expect("a page outside this repository falls back to the releases page",
                UpdateChecker.ParseRelease(Json("{\"tag_name\":\"v0.3.0\",\"html_url\":\"https://example.com/x\"}"))
                    .PageUrl == UpdateChecker.ReleasesPage);
            Expect("malformed JSON is reported as unreadable", IsUnreadable("{\"tag_name\":"));
            Expect("a reply without a tag is reported as unreadable", IsUnreadable("{\"message\":\"Not Found\"}"));
            Expect("a tag that is not a version is reported as unreadable", IsUnreadable("{\"tag_name\":\"nightly\"}"));

            Console.WriteLine(failures == 0 ? "All update checker checks passed." : failures + " check(s) failed.");
            return failures == 0 ? 0 : 1;
        }
    }
}
