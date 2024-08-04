
import { useEffect, useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import  useFetch  from "../../tools/useFetch";
import { useAuth } from '../../tools/AuthContext';
import fetchFromEndpoint from "../../tools/fetchFromEndpoint";

const Recommendations = () => {
    const navigate = useNavigate();
    const [isLoading, setIsLoading] = useState(true);
    const [errorMessage, setErrorMessage] = useState(null);
    const [locationUpdated, setLocationUpdated] = useState(false);
    const [isRecommendationsLoaded, setIsRecommendationsLoaded] = useState(false);
    const [recommendations, setRecommendations] = useState(null);
    const [recommendationsList, setRecommendationsList] = useState([]);// []{id, dog_name, picture}
    
    const { sendJsonMessage, loggedIn, login } = useAuth(); 
    // Use custom hook to fetch bio data
    const { data: bioData, isPending, error } = useFetch("/me/bio");


    useEffect(() => {
        if (error) {
            setErrorMessage(error.message);
        }
    }, [error]);

    // Update location if needed
    useEffect(() => {
        // Connect websocket if not already connected
        if (!loggedIn && !isPending && !error) {
            login();
        }
        const abortController = new AbortController(); // Create an instance of AbortController
        const signal = abortController.signal; // Get the signal to pass to fetch
        // Check if the first fetch is completed and was successful
        if (!isPending && bioData && !error && !locationUpdated) {
            setLocationUpdated(false);
            const locationInfo = bioData?.preferred_location;
            if (locationInfo === "Live") {
                navigator.geolocation.getCurrentPosition((position) => {
                    const { latitude, longitude } = position.coords;
                    sendLocation({ latitude, longitude }, { signal })
                        .then((error)=> {
                            if (error) {
                                if (error.status === 401) {
                                    navigate("/login");
                                } else {
                                    setErrorMessage(error.message);
                                }
                            }
                        
                            setLocationUpdated(true);
                        }).catch((error) => {
                            if (error.name === "AbortError") {
                            } else {
                                setErrorMessage(error.message);
                            }
                        });
                });
            } else {
                setLocationUpdated(true);
            }
        }
        return () => abortController.abort(); 
    }, [isPending, bioData, error, locationUpdated, loggedIn, login, navigate]); 
    
    // Fetch recommendation-id's
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
        if (locationUpdated && bioData && !recommendations && !isRecommendationsLoaded) {
           fetchFromEndpoint("http://localhost:3000/recommendations", {signal})
                .then(({ data, error }) => {
                if (error) {
                    if (error.status === 401) {
                        navigate("/login");
                    } else {
                        setErrorMessage(error.message);
                    }
                } else {
                    setIsRecommendationsLoaded(true);
                    setRecommendations(data.ids);
                }
              }).catch((error) => {
                if (error.name === "AbortError") {
                } else {
                    setErrorMessage(error.message);
                }
            });
        }
        return () => abortController.abort(); 
    }, [locationUpdated, bioData, isRecommendationsLoaded, recommendations, navigate]); 

    // Fetch data for each recommendation id
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
        const recommendationsMap = new Map();
        if (recommendations && recommendations.length > 0 && isRecommendationsLoaded) { 
            setRecommendationsList([]);
            Promise.allSettled(recommendations.map((id) => 
                fetchFromEndpoint(`http://localhost:3000/users/${id}`, {signal})
                    .then(({ data, error }) => {
                        if (error) {
                            if (error.status === 401) {
                                navigate("/login");
                            } else {
                                setErrorMessage(error.message);
                            }
                        } else {
                            recommendationsMap.set(Number(data.id), data);
                        }
                    })
                    .catch((error) => {
                        if (error.name === "AbortError") {
                        } else {
                            setErrorMessage(error.message);
                        }
                    })
                    )).finally(() => {
                        // Sort the recommendationsList based on the order of recommendations
                        const sortedRecommendationsList = recommendations.map((id) => recommendationsMap.get(id)).filter(Boolean);
                        setRecommendationsList(sortedRecommendationsList);
                        setIsLoading(false);
            });
        } else if ((!recommendations || recommendations.length === 0) && isRecommendationsLoaded && isLoading) {
            setIsLoading(false);
        }
        return () => abortController.abort(); 
    }, [recommendations, isRecommendationsLoaded, isLoading, navigate]);

    const sendLocation = async ({ latitude, longitude }, {signal}) => {
        const locationResponse = await fetch("http://localhost:3000/handle_live", {
            method: "PATCH",
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

    // Send connection request to user with userId
    const handleSendRequest = useCallback((userId) => {
        const dataObject = { id: userId };
        sendJsonMessage({ event: "send_request", data: dataObject });
        // Update recommendationsList by removing the recommendation with userId
        setRecommendationsList((prevList) => prevList.filter((user) => user.id !== userId));
        
    }, [sendJsonMessage]);

    // Reject recommendation for user with userId
    const handleRejectRequest = useCallback((userId) => {
        const dataObject = { id: userId };
        sendJsonMessage({ event: "reject_recommendation", data: dataObject });
        // Update recommendationsList by removing the recommendation with userId
        setRecommendationsList((prevList) => prevList.filter((user) => user.id !== userId));
    }, [sendJsonMessage]);
    
    // Create recommendation cards
    const makeRecommendationCards = (recommendationsList) => {
        if (!recommendationsList || recommendationsList.length === 0) {
            return (
                <div className="card centered">
                    <h3>Sorry, no recommendations available at the moment.</h3>
                </div>
            );
        }

        return recommendationsList.map((dogData) => (
            <div key={dogData.id} className="card userCard">
                <img className="cardPicture" 
                    src={
                        dogData.picture
                        ? dogData.picture
                        : `${process.env.PUBLIC_URL}/images/defaultProfile.png`
                    } 
                    alt="profile picture, click to see profile" 
                    onClick={() => navigate(`/profile/${dogData.id}`)} />
                <div className="nameAndButtons">
                    <p>{dogData.dog_name}</p>
                    <div className="buttonContainer">
                        <button className="button userCardButton" 
                            onClick={() => handleSendRequest(dogData.id)}>
                            <img 
                                src={`${process.env.PUBLIC_URL}/images/accept.png`} 
                                alt="Send connection request" />
                        </button>
                        <button className="button userCardButton" 
                            onClick={() => handleRejectRequest(dogData.id)}>
                                <img 
                                    src={`${process.env.PUBLIC_URL}/images/dismiss.png`} 
                                    alt="Dismiss recommendation" />
                        </button>
                    </div>
                </div>
                
            </div>
        ));
    };
    
return (
    <div className="recommendations">
        <h2>Recommendations</h2>
        {errorMessage && <div className="errorBox">Error:<br />{errorMessage}</div>}
        {isLoading && !errorMessage &&
            <div className="card centered">
                <h3>Updating your recommendations...</h3>
                <p>This might take few seconds if you are using live location.</p>
                <img className="loadingScreenPicture" src={`${process.env.PUBLIC_URL}/images/loadingScreenDog.png`} alt="Loading..."></img>
            </div>}
        <div className="twoColumnCard">
            {!isLoading && makeRecommendationCards(recommendationsList)}
        </div>
    </div>
);
};

export default Recommendations;
