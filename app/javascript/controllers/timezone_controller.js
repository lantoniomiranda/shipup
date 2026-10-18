import { Controller } from "@hotwired/stimulus"

// Tells the server which time zone this browser is in (cookie), so people's clocks, meeting
// times and dates default to their own without any setup. See ApplicationController#follow_browser_time_zone.
export default class extends Controller {
  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (zone) document.cookie = `browser_time_zone=${encodeURIComponent(zone)}; path=/; max-age=31536000; samesite=lax`
  }
}
