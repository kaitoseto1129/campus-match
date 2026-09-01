// iOS版 AuthManager.eligibleForOnboardingTutorialKey / hasSeenXTutorial(@AppStorage)と同じ考え方。
// サインアップ直後だけ対象にし、各タブで一度見たら二度と出さない。
const ELIGIBLE_KEY = "eligibleForOnboardingTutorial";

export function markEligibleForOnboardingTutorial() {
  try {
    localStorage.setItem(ELIGIBLE_KEY, "true");
  } catch {
    // localStorageが使えない環境では何もしない(チュートリアルが出ないだけで実害はない)。
  }
}

export function isEligibleForOnboardingTutorial(): boolean {
  try {
    return localStorage.getItem(ELIGIBLE_KEY) === "true";
  } catch {
    return false;
  }
}

export function hasSeenTutorial(key: string): boolean {
  try {
    return localStorage.getItem(`hasSeen${key}Tutorial`) === "true";
  } catch {
    return false;
  }
}

export function markSeenTutorial(key: string) {
  try {
    localStorage.setItem(`hasSeen${key}Tutorial`, "true");
  } catch {
    // ignore
  }
}
