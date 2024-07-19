import { SocketContext } from "../../socketContext";
import { useEffect, useContext, useState } from "react";
import { useNavigate } from "react-router-dom";
import  useFetch  from "../../tools/useFetch";

const Recommendations = () => {
    const socket = useContext(SocketContext);
    const navigate = useNavigate();
    const [isLoading, setIsLoading] = useState(true);
    const [errorMessage, setErrorMessage] = useState(null);
    const [location, setLocation] = useState(null);


    
    // Use custom hook to fetch data
    const { data: bioData, isPending, error } = useFetch("/me/bio");
    const { data: recommendations, isPending: isRecommendationsPending, error: recommendationsError } = useFetch("/recommendations");

    useEffect(() => {
        if (error) {
            setErrorMessage(error.message);
            setIsLoading(false);
            return;
        }
    
        const locationInfo = bioData?.location_option;
        if (locationInfo === "Live") {
            navigator.geolocation.getCurrentPosition((position) => {
                const { latitude, longitude } = position.coords;
                setLocation({ latitude, longitude });
            });
        }
    }, [bioData, error]); // Add dependencies as needed
    
    useEffect(() => {
        if (location) {
            sendLocation();
        }
    }, [location]); 
    
    

    

    const sendLocation = async () => {
        const locationResponse = await fetch("/handle_location", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ location }),
        });
        if (!locationResponse.ok) {
            const errorResponse = await locationResponse.json();
            setErrorMessage("Failed to update location: " + errorResponse.Message);
            return;
        }
    };
    


    


    
return (
    <div className="recommendations">
        <h2>Recommendations</h2>
    </div>


);
};

    

export default Recommendations;
