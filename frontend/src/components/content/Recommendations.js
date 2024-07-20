
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import  useFetch  from "../../tools/useFetch";

const Recommendations = () => {
    const navigate = useNavigate();
    const [isLoading, setIsLoading] = useState(true);
    const [errorMessage, setErrorMessage] = useState(null);
    const [locationUpdated, setLocationUpdated] = useState(false);
    const [isRecommendationsLoaded, setIsRecommendationsLoaded] = useState(false);
    const [recommendations, setRecommendations] = useState(null);
    const [recommendationsList, setRecommendationsList] = useState([]);// []{id, dog_name, picture}
    
    // Use custom hook to fetch bio data
    const { data: bioData, isPending, error } = useFetch("/me/bio");

    // Update location if needed
    useEffect(() => {
        const abortController = new AbortController(); // Create an instance of AbortController
        const signal = abortController.signal; // Get the signal to pass to fetch
        // Check if the first fetch is completed and was successful
        if (!isPending && bioData && !error && !locationUpdated) {
            // Trigger the second fetch here
            setLocationUpdated(false);
            const locationInfo = bioData?.preferred_location;
            if (locationInfo === "Live") {
                navigator.geolocation.getCurrentPosition((position) => {
                    const { latitude, longitude } = position.coords;
                    sendLocation({ latitude, longitude }, { signal }).then((error)=> {
                        if (error) {
                            setErrorMessage(error.message);
                        }
                    
                        setLocationUpdated(true);
                    }).catch((error) => {
                        if (error.name === "AbortError") {
                            console.log("Fetch aborted");
                        }
                    });
                });
            } else {
                setLocationUpdated(true);
            }
        }
        return () => abortController.abort(); // Cleanup function to abort fetch on component unmount
    }, [isPending, bioData, error, locationUpdated]); 
    
    // Fetch recommendation-id's
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
        // fetch recommendations
        if (locationUpdated && bioData && !recommendations && !isRecommendationsLoaded) {
           fetchRecommendations({signal}).then(({ recommendationsData, error }) => {
                if (error) {
                    setErrorMessage(error.message);
                } else {
                    setIsRecommendationsLoaded(true);
                    setRecommendations(recommendationsData);
                }
              }).catch((error) => {
                if (error.name === "AbortError") {
                    console.log("Fetch aborted");
                }
            });
        }
        return () => abortController.abort(); 
    }, [locationUpdated, bioData, isRecommendationsLoaded, recommendations]); 

    // Fetch data for each recommendation id
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
        if (recommendations && recommendations.length > 0 && isRecommendationsLoaded && isLoading) { 
            // for each id in recommendations, fetch the data
            Promise.allSettled(recommendations.map((id) => 
                fetchRecommendationData(id, {signal})
                    .then(({ recommendationData, error }) => {
                        if (error) {
                            setErrorMessage(error.message);
                        } else {
                            setRecommendationsList((prevList) => [...prevList, recommendationData]);
                        }
                    })
                    .catch((error) => {
                        if (error.name === "AbortError") {
                            console.log("Fetch aborted");
                        } 
                    })
            )).finally(() => {
                setIsLoading(false);
            });
        } else if ((!recommendations || recommendations.length === 0) && isRecommendationsLoaded && isLoading) {
            setIsLoading(false);
        }
        return () => abortController.abort(); 
    }, [recommendations, isRecommendationsLoaded, isLoading]);


    const fetchRecommendationData = async (id, {signal}) => {
        const response = await fetch(`/users/${id}`, { signal });
        if (!response.ok) {
            const errorResponse = await response.json();
            const error = new Error();
            error.status = response.status;
            error.message = errorResponse.Message || "Unknown error";
            return { recommendationData: null, error };
        }
        const data = await response.json(); // data.id, data.dog_name, data.picture
        return { recommendationData: data, error: null };
    };
    

    const fetchRecommendations = async ({signal}) => {
        const response = await fetch("/recommendations", { signal });
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

    const sendLocation = async ({ latitude, longitude }, {signal}) => {
        const locationResponse = await fetch("/handle_live", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ latitude, longitude }),
            signal: signal
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
    
    const makeRecommendationCards = (recommendationsList) => {
        if (!recommendationsList || recommendationsList.length === 0) {
            return (
                <div className="card centered">
                    <h3>Sorry, no recommendations available at the moment.</h3>
                </div>
            );
        }
        // Socket action needed for the buttons
        return recommendationsList.map((dogData) => (
            <div key={dogData.id} className="card userCard">
                <img className="cardPicture" src={dogData.picture} alt="dog" onClick={() => navigate(`/profile/${dogData.id}`)} />
                <div className="nameAndButtons">
                    <p>{dogData.dog_name}</p>
                    <div className="buttonContainer">
                        <img className="button userCardButton" src={`${process.env.PUBLIC_URL}/images/accept.png`} alt="Send connection request" />
                        <img className="button userCardButton" src={`${process.env.PUBLIC_URL}/images/dismiss.png`} alt="Dismiss recommendation" />
                    </div>
                </div>
                
            </div>
        ));
    };
    
return (
    <div className="recommendations">
        <h2>Recommendations</h2>
        {errorMessage && <div className="errorBox">Error:<br />{errorMessage}</div>}
        {isLoading && 
            <div className="card centered">
                <h3>Updating your recommendations...</h3>
                <img className="loadingScreenPicture" src={`${process.env.PUBLIC_URL}/images/loadingScreenDog.png`}></img>
            </div>}
        <div className="twoColumnCard">
            {!isLoading && makeRecommendationCards(recommendationsList)}
        </div>
    </div>
);
};

export default Recommendations;
