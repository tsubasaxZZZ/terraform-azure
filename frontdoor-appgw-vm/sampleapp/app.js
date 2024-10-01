const express = require('express')
const app = express()
const port = 8080

app.get('/', (req, res) => {
  res.set('Cache-Control', 'no-store')
  console.log(console.log(JSON.stringify(req.headers)))
  res.send('<table border=1><tr><th>Header</th><th>Value</th></tr>' + Object.keys(req.headers).map((key) => `<tr><td>${key}</td><td>${req.headers[key]}</td></tr>`).join('') + '</table>')
})

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
})
