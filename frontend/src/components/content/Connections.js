import { useAuth } from "../../tools/AuthContext";
import { useNavigate } from "react-router-dom";
import { useState, useEffect, useCallback } from "react";
import useFetch from "../../tools/useFetch";
import fetchUserData from "../../tools/fetchUserInfo";

const Connections = () => {
    const { loggedIn, friendRequests, sendJsonMessage, login, clearFriendNotification } = useAuth();
    const navigate = useNavigate();
    const [errorMessage, setErrorMessage] = useState(null);
    const [isLoading, setIsLoading] = useState(true);
    const [connections, setConnections] = useState([]);
    const [requests, setRequests] = useState([]);

    // use custom hook to fetch connections
    const { data: connectionsData, isPending, error } = useFetch("/connections");

    useEffect(() => {
        if (error) {
            setErrorMessage(error.message);
        }
    }, [error]);

    // Get other information needed for connections
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
        // Connect websocket if not already connected
        if (!loggedIn && !isPending && !error) {
            login();
        }
        if (!isPending && !error && connectionsData?.ids?.length > 0) {
            setConnections([]);
            // Trigger the second fetch here
            Promise.allSettled(connectionsData.ids.map((id) => 
                fetchUserData(id, {signal})
                    .then(({ userData, error }) => {
                        if (error) {
                            setErrorMessage(error.message);
                        } else {
                            setConnections((prevList) => [...prevList, userData]);
                        }
                    })
                    .catch((error) => {
                        if (error.name === "AbortError") {
                            console.log("Fetch aborted");
                        } 
                    })
                ));
        } 
        return () => abortController.abort(); 
    }, [isPending, connectionsData?.ids]);

    // Get other information needed for requests
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
        if ( friendRequests.length > 0 && !error) {
            setIsLoading(true);
            setRequests([]);
            Promise.allSettled(friendRequests.map((id) => 
                fetchUserData(id, {signal})
                    .then(({ userData, error }) => {
                        if (error) {
                            setErrorMessage(error.message);
                        } else {
                            setRequests((prevList) => [...prevList, userData]);
                        }
                    })
                    .catch((error) => {
                        if (error.name === "AbortError") {
                            console.log("Fetch aborted");
                        } 
                    })
            )).finally(() => {
                if (requests.length !== 0) {
                    setIsLoading(false);
                }
            });
        }

        return () => abortController.abort(); 
    }, [friendRequests]);

    const handleRemoveConnection = useCallback((userId) => {
        const dataObject = { id: userId };
        sendJsonMessage({ event: "decline_request", data: dataObject });
        // Remove the user from connections
        setConnections((prevList) => prevList.filter((user) => user.id !== userId));
    }, [sendJsonMessage]);

    const handleRemoveRequest = useCallback((userId) => {
        const dataObject = { id: userId };
        sendJsonMessage({ event: "decline_request", data: dataObject });
        // Remove the user from requests
        setRequests((prevList) => prevList.filter((user) => user.id !== userId));
    }, [sendJsonMessage]);

    const handleAcceptRequest = useCallback((userId) => {
        const dataObject = { id: userId };
        console.log(dataObject);
        sendJsonMessage({ event: "accept_request", data: dataObject });
        // Find the user in requests
        const userObject = requests.find((user) => user.id === userId);
        // Remove the user from requests
        setRequests((prevList) => prevList.filter((user) => user.id !== userId)); 
        // Add the user to connections
        setConnections((prevList) => [userObject, ...prevList]);
    }, [sendJsonMessage]);

    useEffect(() => {
        if (requests.length === 0 && friendRequests.length !== 0 && !isLoading) {
            clearFriendNotification();
        }
    }, [requests])
    
    const makeConnectionCards = (connections) => {
        if (!connections || connections.length === 0) {
            return (
                <div className="card centered">
                    <h3>You have no connections.</h3>
                </div>
            );
        }

        return connections.map((dogData) => (
            <div key={dogData.id} className="card userCard">
                <img className="cardPicture" 
                    src={
                        dogData.picture
                        ? dogData.picture
                        : `${process.env.PUBLIC_URL}/images/defaultProfileDog.png`
                    } 
                    alt="dog" 
                    onClick={() => navigate(`/profile/${dogData.id}`)} />
                <div className="nameAndButtons">
                    <p>{dogData.dog_name}</p>
                    <div className="buttonContainer">
                        <button className="button userCardButton" 
                            onClick={() => navigate(`/chat/${dogData.id}`)}>
                            <img 
                                src={`${process.env.PUBLIC_URL}/images/chat.png`} 
                                alt="Open chat with this connection" />
                        </button>
                        <button className="button userCardButton" 
                            onClick={() => handleRemoveConnection(dogData.id)}>
                            <img 
                                src={`${process.env.PUBLIC_URL}/images/dismiss.png`} 
                                alt="Remove connection" />
                        </button>
                    </div>
                </div>
                
            </div>
        ));
    };

    const makeRequestCards = (requests) => {
        if (!requests || requests.length === 0) {
            return <></>;
        }

        return requests.map((dogData) => (
            <div key={dogData.id} className="card userCard">
                <img className="cardPicture" 
                    src={
                        dogData.picture
                        ? dogData.picture
                        : `${process.env.PUBLIC_URL}/images/defaultProfileDog.png`
                    } 
                    alt="dog" 
                    onClick={() => navigate(`/profile/${dogData.id}`)} />
                <div className="nameAndButtons">
                    <p>{dogData.dog_name}</p>
                    <div className="buttonContainer">
                        <button className="button userCardButton" 
                            onClick={() => handleAcceptRequest(dogData.id)}>
                            <img 
                                src={`${process.env.PUBLIC_URL}/images/accept.png`} 
                                alt="Accept request" />
                        </button>
                        <button className="button userCardButton" 
                            onClick={() => handleRemoveRequest(dogData.id)}>
                            <img 
                                src={`${process.env.PUBLIC_URL}/images/dismiss.png`} 
                                alt="Dismiss request" />
                        </button>
                    </div>
                </div>
                
            </div>
        ));
    }





    return (
    <div>
        <h2>Connections</h2>
        {errorMessage && <div className="errorBox">Error:<br />{errorMessage}</div>}
        {requests?.length > 0 && <h3>New connection requests:</h3>}
        <div className="twoColumnCard">
            {makeRequestCards(requests)}
        </div>
        <h3>My connections:</h3>
        <div className="twoColumnCard">
            {makeConnectionCards(connections)}
        </div>
        
    </div>

    )
  
} 
export default Connections;