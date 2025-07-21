// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.VolumeSlider = {
  mounted() {
    let lastSent = 0
    let pending = null

    this.el.addEventListener("input", e => {
      const value = e.target.value
      const now = Date.now()

      const send = () => {
        this.pushEventTo(this.el, "set_volume", { value })  // 👈 FIXED LINE
        lastSent = Date.now()
      }

      if (now - lastSent > 100) {
        send()
      } else {
        if (pending) clearTimeout(pending)
        pending = setTimeout(send, 100 - (now - lastSent))
      }
    })
  }
}

Hooks.RepeatClick = {
  mounted() {
    let timeout, interval
    const holdDelay = 500
    const repeatRate = 100

    const send = () => {
      this.pushEventTo(this.el, "set_volume", {
        value: this.el.getAttribute("phx-value-value")
      })
    }

    const clear = () => {
      clearTimeout(timeout)
      clearInterval(interval)
    }

    this.el.addEventListener("mousedown", (e) => {
      e.preventDefault()
      send()
      timeout = setTimeout(() => {
        interval = setInterval(send, repeatRate)
      }, holdDelay)
    })

    this.el.addEventListener("mouseup", clear)
    this.el.addEventListener("mouseleave", clear)
    this.el.addEventListener("touchend", clear)
  }
}


export default Hooks


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

