## Inspiration
Most of us struggle to find a free parking spot during rush hour or at a new location.
**ParkHere!** is an attempt to find the most convenient spot quickly and easily.
How many times have been in a situation when you need to constantly check your phone so that you don't get a ticket due to overstaying in your parking spot? ParkHere automatically takes care of that for you so that you can focus on something more important.
## What it does
ParkHere! automatically takes in your location data and detects if you've parked using our motion-based algorithm. We are using a database from the Sacramento government's website and using that data to identify and warn the user if it is a no-parking zone. We also let the user view parking spots near them and let them choose a spot they want and allow them to use google maps to navigate to that. Once the user has parked, we ask the user to confirm that and start a timer based on the parking spot and show a notification once the time is up.
## How we built it
We used Flutter and dart to build the application. We used location services API, to locate our users. We read parking spot data from the Sacramento government site into our program to find the closest spots for our users. We are using google maps API to display the parking spots and the user's location.
## Challenges we ran into
We were able to overcome the challenge of running a background parking timer for our users. In order to add the parking data, we had to create a CSV file with all the parking spots in Sacramento county along with how long each parking spot allows you to park.
## Accomplishments that we're proud of
We are proud to be able to use location services to locate the nearest open spots for users.
We are also proud to be able to alert users with timely parking information.
## What we learned
We learned how to import APIs, run a background timer in flutter, and display in-app and background notifications.
## What's next for ParkHere!
**ParkHere!** will get more features like navigating users back to the location of their cars. 
Also, to increase the efficiency of locating open spots, ParkHere will support a database of its parked users such that occupied spots can be hidden from the rest of the users. We are planning on creating a recommendation system that uses data such as proximity to your location, how long can you park, amount of cars parked near you, and the orientation of the cars parked to suggest better spots for you to park in.
