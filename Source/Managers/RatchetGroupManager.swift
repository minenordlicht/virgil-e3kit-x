//
// Copyright (C) 2015-2019 Virgil Security Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     (1) Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//
//     (2) Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in
//     the documentation and/or other materials provided with the
//     distribution.
//
//     (3) Neither the name of the copyright holder nor the names of its
//     contributors may be used to endorse or promote products derived from
//     this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
// IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>
//

import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet

internal class RatchetGroupManager {
    internal let identity: String
    internal let localGroupStorage: FileRatchetGroupStorage
    internal let cloudTicketStorage: CloudRatchetStorage

    private let localKeyStorage: LocalKeyStorage
    private let lookupManager: LookupManager
    private let crypto: VirgilCrypto

    internal init(localGroupStorage: FileRatchetGroupStorage,
                  cloudTicketStorage: CloudRatchetStorage,
                  localKeyStorage: LocalKeyStorage,
                  lookupManager: LookupManager,
                  crypto: VirgilCrypto) {
        self.identity = localGroupStorage.identity
        self.localGroupStorage = localGroupStorage
        self.cloudTicketStorage = cloudTicketStorage
        self.localKeyStorage = localKeyStorage
        self.lookupManager = lookupManager
        self.crypto = crypto
    }

    private func parse(_ rawGroup: RatchetRawGroup) throws -> RatchetGroup {
        // FIXME: Why pass keyStorage and Managers if they all are inside groupManager already

        return try RatchetGroup(rawGroup: rawGroup,
                                crypto: self.crypto,
                                localKeyStorage: self.localKeyStorage,
                                groupManager: self,
                                lookupManager: self.lookupManager)
    }

    internal func store(ticket: RatchetTicket, sharedWith cards: [Card]) throws {
        try self.cloudTicketStorage.store(ticket, sharedWith: cards)
        try self.localGroupStorage.store(ticket: ticket, sessionId: ticket.groupMessage.getSessionId())
    }

    internal func store(session: SecureGroupSession, participants: Set<String>) throws -> RatchetGroup {
        let info = RatchetGroupInfo(initiator: self.identity, participants: participants)
        let rawGroup = RatchetRawGroup(session: session, info: info)

        try self.localGroupStorage.store(rawGroup)

        return try self.parse(rawGroup)
    }

    internal func retrieve(sessionId: Data) -> RatchetGroup? {
        guard let rawGroup = self.localGroupStorage.retrieve(sessionId: sessionId) else {
            return nil
        }

        return try? self.parse(rawGroup)
    }

    internal func pull(sessionId: Data, from card: Card) throws {
        let tickets = try self.cloudTicketStorage.retrieve(sessionId: sessionId,
                                                           identity: card.identity,
                                                           identityPublicKey: card.publicKey)

        guard !tickets.isEmpty else {
            try self.localGroupStorage.delete(sessionId: sessionId)

            throw GroupError.groupWasNotFound
        }

        try self.localGroupStorage.store(tickets: tickets, sessionId: sessionId)
    }

    internal func getTicket(sessionId: Data, epoch: UInt32) -> RatchetTicket? {
        return self.localGroupStorage.retrieveTicket(sessionId: sessionId, epoch: epoch)
    }

    internal func delete(sessionId: Data) throws {
        try self.cloudTicketStorage.delete(path: sessionId)

        try self.localGroupStorage.delete(sessionId: sessionId)
    }

//    internal func addAccess(to cards: [Card], sessionId: Data) throws {
//        try self.cloudTicketStorage.addRecipients(cards, path: sessionId)
//    }
//
//    internal func reAddAccess(to card: Card, sessionId: Data) throws {
//        try self.cloudTicketStorage.reAddRecipient(card, path: sessionId)
//    }
//
//    internal func removeAccess(identities: Set<String>, to sessionId: Data) throws {
//        try identities.forEach {
//            try self.cloudTicketStorage.removeRecipient(identity: $0, path: sessionId)
//        }
//    }
}
