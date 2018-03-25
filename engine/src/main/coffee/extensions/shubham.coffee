module.exports = {
input = prompt "Enter string to be downloaded as text !"
alert input 
output = input
localStorage.game = JSON.stringify({ input }) 
console.log(JSON.parse(localStorage.game)) 

{
      name: "shubham"
    , prims: {
                "input":input
      }
    }
}
}