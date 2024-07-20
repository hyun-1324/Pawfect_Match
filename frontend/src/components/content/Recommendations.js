import { SocketContext } from "../../socketContext";
import { useEffect, useContext, useState } from "react";
import { useNavigate } from "react-router-dom";
import  useFetch  from "../../tools/useFetch";

const Recommendations = () => {
    const socket = useContext(SocketContext);
    const navigate = useNavigate();
    const [isLoading, setIsLoading] = useState(true);
    const [errorMessage, setErrorMessage] = useState(null);
    const [locationUpdated, setLocationUpdated] = useState(false);
    const [isRecommendationsLoaded, setIsRecommendationsLoaded] = useState(false);
    const [recommendations, setRecommendations] = useState(null);
    


    //socket.connect();
    // Use custom hook to fetch data
    const { data: bioData, isPending, error } = useFetch("/me/bio");
  

    /*function getSocket() {
        // Check if socket is already connected
        if (socket && socket.connected) {
            return socket;
        } else {
            // Connect the socket
            socket.connect();
            console.log("Socket connected");
            return socket;
        }
    }*/
    
    useEffect(() => {
        // Check if the first fetch is completed and was successful
        if (!isPending && bioData && !error && !locationUpdated) {
            // Trigger the second fetch here
            setLocationUpdated(false);
            const locationInfo = bioData?.preferred_location;
            if (locationInfo === "Live") {
                navigator.geolocation.getCurrentPosition((position) => {
                    const { latitude, longitude } = position.coords;
                    sendLocation({ latitude, longitude }).then((error)=> {
                        if (error) {
                            setErrorMessage(error.message);
                        }
                    
                        setLocationUpdated(true);
                    });
                });
            } else {
                setLocationUpdated(true);
            }
            
        }
    }, [isPending, bioData, error, locationUpdated]); 
    

    useEffect(() => {
        // fetch recommendations
        if (locationUpdated && bioData && !recommendations && !isRecommendationsLoaded) {
           fetchRecommendations().then(({ recommendationsData, error }) => {
                if (error) {
                    setErrorMessage(error.message);
                } else {
                    setIsRecommendationsLoaded(true);
                    setRecommendations(recommendationsData);
                }
              });
        }
        
    }, [locationUpdated, bioData, isRecommendationsLoaded, recommendations]); 

    useEffect(() => {
        // fetch all other data needed for the recommendations
        if (recommendations && recommendations.length > 0) {
            
        }
    }, [recommendations]);

    /*useEffect(() => {
        getSocket();
    }, []);*/
    
    

    const fetchRecommendations = async () => {
        const response = await fetch("/recommendations");
        if (!response.ok) {
            const errorResponse = await response.json();
            const error = new Error();
            error.status = response.status;
            error.message = errorResponse.Message || "Unknown error";
            return { recommendationsData: null, error };
        }
        const data = await response.json();
        return { recommendationsData: data.ids, error: null };

    };

    const sendLocation = async ({ latitude, longitude }) => {
        const locationResponse = await fetch("/handle_live", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ latitude, longitude }),
        });
        if (!locationResponse.ok) {
            const errorResponse = await locationResponse.json();
            const error = new Error();
            error.status = locationResponse.status;
            error.message = ("Failed to update location: "+ errorResponse.Message) || "Unknown error";
            return error;
        }
        return null;
    };
    
    /*const makeRecommendationCards = (recommendations) => {
        if (!recommendations.ids || recommendations.ids.length === 0) {
            return;
        }
        return recommendations.ids.map((id) => (
            <div key={id} className="card">
                <img src={`${process.env.PUBLIC_URL}`} alt="dog" />
            </div>
        ));
    };*/
            
        



    


    
return (
    <div className="recommendations">
        <h2>Recommendations</h2>
        {errorMessage && <div className="errorBox">Error:<br />{errorMessage}</div>}

        
    </div>


);
};

    

export default Recommendations;
