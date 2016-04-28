# DelivMyApp [https://delivmy.com]


Is peer to peer delivery application, allow users to place orders from any categories like restaurant, grocery,  dry clearners and others, and add delivery fees, other users can search the map for local orders and deliver it. 

> **Login/signup screen**
  - User signup page to obtain access to application
  - User Email and password to login.

![Alt text](/Document/Login.PNG)

> **Search Map & Collection view**
  - users have option to use map to search for local requests, collection view will show summary for each request (Place name, deliver time, deliver fee, category and user profile)
  - Auto refresh option allow auto update every 15 sec and using 
  - search API using method `"/search"` and parameters: `north east, south west and center points`

![Alt text](/Document/Search.PNG)

> **Select request for delivery**
  - select one of avaiable requests
  - view will popup and show the request details, click accept deliver, request will move to your deliver list.
  - Accept request use method `“/deliver/new”` and parameter: `request_id`
  
![Alt text](/Document/Search_request.PNG)

> **My Request list**
  - My request tab show all requests you placed.
  - Table view show summary info for requests (Place name, deliver time, deliver fee, category and deliver status)
  - Location: show request location
  - Item list: show items count, select to view items details
  - Deliv Info: show profile of delivery user, if request on progress.
  - Receipt: show request receipt if available. 
  - Accept request `"option not available"`
  - Request API using method `“/requests/:id”` and :id is selected `request id`
  
![Alt text](/Document/Requests.PNG)


Request status are:
```
  - open: request open for delivery
  - On Progress: request was accepted by other user and on the way.
  - Completed: request delivered.
  - Closed: request closed or canceled
  - Rejected: User rejected request.
```

> **My deliver list**
  - My deli tab show all deliver accepted by user.
  - table view show summary info for requests (Place name, deliver time, deliver fee, category and requester info)
  - Location: show request location
  - Item list: show items count, select to view items details
  - Requester Info: show profile of requester user.
  - Receipt: Allow user to post receipt “Not available on App”. 
  - submit deliver “Not Available"
  - deliver API using method `“/delivers/:id”` and :id is selected `deliver_id`
  
![Alt text](/Document/Delivers.PNG)
