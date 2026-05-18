export default class FileUploader {
  constructor(file, url, clientMessageId, progressCallback, body = null) {
    this.file = file
    this.url = url
    this.clientMessageId = clientMessageId
    this.progressCallback = progressCallback
    this.body = body
  }

  upload() {
    const formdata = new FormData()
    formdata.append("message[attachment]", this.file)
    formdata.append("message[client_message_id]", this.clientMessageId)
    if (this.body) formdata.append("message[body]", this.body)

    const req = new XMLHttpRequest()
    const csrfToken = document.querySelector("meta[name=csrf-token]")?.content

    req.open("POST", this.url)
    if (csrfToken) req.setRequestHeader("X-CSRF-Token", csrfToken)
    req.upload.addEventListener("progress", this.#uploadProgress.bind(this))

    const result = new Promise((resolve, reject) => {
      req.addEventListener("readystatechange", () => {
        if (req.readyState === XMLHttpRequest.DONE) {
          if (req.status < 400) {
            resolve(req.response)
          } else {
            reject()
          }
        }
      })
    })

    req.send(formdata)
    return result
  }

  #uploadProgress(event) {
    if (event.lengthComputable) {
      const percent = Math.round((event.loaded / event.total) * 100)
      this.progressCallback(percent, this.clientMessageId, this.file)
    }
  }
}
