// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket,
// and connect at the socket path in "lib/web/endpoint.ex".
//
// Pass the token on params as below. Or remove it
// from the params if you are not using authentication.
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/3" function
// in "lib/web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket, _connect_info) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, connect to the socket:
socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("room:lobby", {})
let chatInput         = document.querySelector("#chat-input")
let messagesContainer = document.querySelector("#messages")
let amountInput = document.querySelector("#amount")
let receiver = document.querySelector("#receiver")

var list_of_receiver =[]
var index = 1;
var transaction = 1;

// channel.on('list_of_public_keys', msg => {
//   list_of_receiver = msg.list_of_public_keys
//   for(var element in list_of_receiver)
//   {
//    var opt = document.createElement("option");
//    opt.value= index;
//    opt.innerHTML = "publicKey"+index; // whatever property it has
//    // then append it to the select element
//    receiver.appendChild(opt);
//    index++;
//   }
// })

document.getElementById("myForm").addEventListener("submit", myFunction);

function myFunction() {
  channel.push("mining_amount", {amount: amountInput.value, receiver: receiver.value})
  amountInput.value = ""
  receiver.value= ""
   let messageItem = document.createElement("li")
   messageItem.innerText = `Transaction Completed`
  // transaction = transaction + 1
  messagesContainer.appendChild(messageItem)
}



channel.on("new_msg", payload => {
  let messageItem = document.createElement("li")
  messageItem.innerText = `[${Date()}] ${payload.body}`
  messagesContainer.appendChild(messageItem)
})

amountInput.addEventListener("keypress", event =>{
  if(event.keyCode === 13){
    channel.push("mining_amount", {body: amountInput.value})
    amountInput.value = ""
  }
})

receiver.addEventListener("keypress", event =>{
  if(event.keyCode === 13){
    channel.push("receiver", {body: chatInput.value})
  }
})

var ctx1 = document.getElementById("myChart1");
var myBarChart = new Chart(ctx1, {
    type: 'bar',
    data: {
        labels: ["Total transcations", "Commited transactions", "UnCommited transactions"],
        datasets: [{
            label: "transcations",
            data: [0, 0, 0],
            backgroundColor: [
                'rgba(255, 99, 132, 0.2)',
                'rgba(54, 162, 235, 0.2)',
                'rgba(255, 206, 86, 0.2)',
            ],
            borderColor: [
                'rgba(255,99,132,1)',
                'rgba(54, 162, 235, 1)', 
                'rgba(255, 206, 86, 1)',           
            ],
            borderWidth: 1
        }]
    },
    options: {
        scales: {
            yAxes: [{
                ticks: {
                    beginAtZero:true
                }
            }]
        }
    }
});  
var ctx2 = document.getElementById("myChart2")
var myLineChart = new Chart(ctx2, {
  type: 'line',
  data: {
    datasets: [{
      label: 'Bitcoins transacted',
      data: [],
      backgroundColor: "rgba(153,255,51,0.4)"
    },
  ]
  },
  options:  {
    title : {
      display: true,
      text: "Amount of bitcoins transferred per transaction"
    },
    scales: {
        yAxes: [{
            ticks: {
                beginAtZero:true
            },
            scaleLabel: {
              display: true,
              labelString: "bitcoins" 
            }
        }],
        xAxes: [{
          type: 'linear',
          position: 'bottom',
          ticks: {
            beginAtZero:true
          },
          scaleLabel: {
            display: true,
            labelString: "transactions" 
          }
        }]
    }
}
});


var ctx3= document.getElementById("myChart3")

var myLineChart2 = new Chart(ctx3, {
  type: 'line',
  data: {
    datasets: [
    {
      label: 'Bitcoins mined',
      data: [],
      backgroundColor: "rgba(54, 162, 235, 0.2)"
    },
  ]
  },
  options:  {
    title : {
      display : true,
      text: 'Bitcoins commited to blockchain per mining operation'
    },
    scales: {
        yAxes: [{
            ticks: {
                beginAtZero:true
            },
            scaleLabel: {
              display: true,
              labelString: 'Bitcoins'
            }
        }],
        xAxes: [{
          type: 'linear',
          position: 'bottom',
          ticks: {
            beginAtZero:true
          },
          scaleLabel: {
            display: true,
            labelString: 'Mining operations'
          }
        }]
    }
}
});

var dict = {
  "transcation_count" : 0,
  "commited_transcation_count" : 0,
  "transaction_amount" : 0,
  "bitcoin_mined" : 0,
};
var count=0;
var count2=0;

channel.on('new_transaction', msg => {
  //document.getElementById('status').innerHTML = msg.response
  dict["transcation_count"] = dict["transcation_count"] + msg.transaction

   myBarChart.data.datasets[0].data[0] = dict["transcation_count"]
   myBarChart.update()

  //document.getElementById('timer').innerHTML = dict["count"] + msg.transaction
})

channel.on('new_commited_transaction', msg => {
  dict["commited_transcation_count"] = dict["commited_transcation_count"] + msg.commited_transaction
  myBarChart.data.datasets[0].data[1] = dict["commited_transcation_count"] 

  //TODO: rectify or remove this
  myBarChart.data.datasets[0].data[2]= dict["transcation_count"]- dict["commited_transcation_count"]
  myBarChart.update()
})

channel.on('new_amount', msg =>{
  dict["transaction_amount"] = dict["transaction_amount"] + msg.amount
  myLineChart.data.datasets[0].data.push({ x: count,
    y: dict["transaction_amount"]})
    
  count = count + 1 
  myLineChart.update()
})

channel.on('new_mined_amount', msg =>{
  dict["bitcoin_mined"] = dict["bitcoin_mined"] + msg.mined_amount
  myLineChart2.data.datasets[0].data.push({x:count2,
     y: dict["bitcoin_mined"] })
  count2= count2 + 1
  myLineChart2.update()
})


channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp)
  console.log("hiiiii")
  for(var element in list_of_receiver)
  {
   var opt = document.createElement("option");
   opt.value= index;
   opt.innerHTML = "publicKey"+index; // whatever property it has
   // then append it to the select element
   receiver.appendChild(opt);
   index++;
  }
})
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
