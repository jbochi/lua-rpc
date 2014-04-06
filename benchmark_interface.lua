interface { name = inttestes,
            methods = {
               foo = {
                 resulttype = "double",
                 args = {{direction = "in",
                          type = "double"},
                         {direction = "in",
                          type = "double"},
                         {direction = "inout",
                          type = "double"}
                        }
               },
               foo2 = {
                 resulttype = "void",
                 args = {}
               },
               boo = {
                 resulttype = "double",
                 args = {{direction = "in",
                          type = "string"}}
               }
             }
            }
