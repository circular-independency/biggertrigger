const ws = new WebSocket("ws://YOUR_IP:8765");

ws.onopen = () => console.log("connected");

ws.onmessage = (event) => {
  console.log("server:", event.data);
};

function sendUsername() {
  const name = document.getElementById("username").value;
  ws.send(name);
}