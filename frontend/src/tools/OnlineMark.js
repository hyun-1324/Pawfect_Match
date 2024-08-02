
const OnlineMark = (userId, statuses) => {

    const userStatus = statuses?.find((status) => status.id === String(userId));
    if (userStatus?.status === true) {
        return (
            <div className="onlineMark online"></div>
        );
    } else {
        return (
            <div className="onlineMark offline"></div>
        );
    }
}

export default OnlineMark;