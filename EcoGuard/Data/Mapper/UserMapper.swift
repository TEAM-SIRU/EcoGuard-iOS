nonisolated extension MyProfileResponseDTO {
    var sessionUser: SessionUser {
        SessionUser(userId: userId, name: name, studentNumber: studentNumber, grade: grade, classNo: classNo)
    }
}

extension SessionUser {
    func toDomain() -> CurrentUser {
        CurrentUser(id: String(userId), name: name, studentNumber: studentNumber, grade: grade, classNumber: classNo)
    }
}
