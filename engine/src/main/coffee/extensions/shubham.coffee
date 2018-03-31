
module.exports = 
{

       input = prompt "Enter string to be downloaded as text !"
       alert input 
       fs = require "fs"
       fs.writeFile "UserInput.txt",
       myFile = JSON.stringify(input) 
       console.log(JSON.parse(myFile))

         (error) -> console.error("Error writing file", error) if error

 {
    {  name: "shubham"
    , prims: {
                "input":input
      }
    }
 }
}